# frozen_string_literal: true

# Assigns every existing Stream channel to its community's team, ahead of
# enabling Stream's multi-tenant mode. Until that mode is switched on, the
# `team` field is inert, so plan/apply can be run (and re-run) against a live
# app without changing what anyone sees.
#
#   backfill = StreamTeamBackfill.new(legacy_slug: "crow-woods")
#   backfill.plan     # => [Row, ...]  what would change, and why
#   backfill.apply!   # writes `team` on every channel that needs it
#   backfill.verify   # => report hash; must be :ok before flipping the toggle
#   backfill.enable_multi_tenant!  # verifies, then flips the app setting
class StreamTeamBackfill
  CHANNEL_FILTER = { "type" => { "$eq" => "team" } }.freeze
  SORT = { "created_at" => -1 }.freeze
  PAGE_SIZE = 100

  class UnattributedChannels < StandardError; end
  class NotReady < StandardError; end

  Row = Struct.new(:type, :id, :current_team, :community_slug, :resolved_team, :source, keyword_init: true) do
    def changed?
      resolved_team.present? && current_team != resolved_team
    end

    def unattributed?
      resolved_team.nil?
    end
  end

  def initialize(client: StreamChatClient.client, legacy_slug: nil)
    @client = client
    @legacy_slug = legacy_slug.presence
  end

  # One row per channel, with the team it should belong to and how that was decided:
  #   :community_slug - the channel's own community_slug metadata
  #   :id_prefix      - the channel id starts with "<slug>-"
  #   :legacy         - an old unprefixed default channel, assigned to legacy_slug
  #   nil             - could not be attributed; apply! refuses to run
  def plan
    @plan ||= all_channels.map { |channel| build_row(channel) }
  end

  def apply!
    unattributed = plan.select(&:unattributed?)
    if unattributed.any?
      raise UnattributedChannels, "Cannot attribute channels: #{unattributed.map(&:id).join(', ')}"
    end

    plan.select(&:changed?).each do |row|
      @client.channel(row.type, channel_id: row.id).update_partial({ "team" => row.resolved_team })
    end
  end

  # Which Stream app we're talking to and whether teams are being enforced.
  def app_info
    app = @client.get_app_settings["app"]
    {
      name: app["name"],
      multi_tenant_enabled: app["multi_tenant_enabled"] == true
    }
  end

  def verify
    info = app_info
    channels = all_channels

    channels_without_team = channels.select { |c| c["team"].blank? }.map { |c| c["id"] }
    channels_mismatched = channels.select do |c|
      c["team"].present? && c["community_slug"].present? && c["team"] != c["community_slug"]
    end.map { |c| c["id"] }
    users_without_teams = find_users_without_teams

    {
      app_name: info[:name],
      multi_tenant_enabled: info[:multi_tenant_enabled],
      channels_without_team: channels_without_team,
      channels_mismatched: channels_mismatched,
      users_without_teams: users_without_teams,
      ok: channels_without_team.empty? && channels_mismatched.empty? && users_without_teams.empty?
    }
  end

  # Turns on Stream's multi-tenant enforcement, but only once every channel and
  # user is assigned - otherwise they'd lose access the moment it flips.
  # Returns false if it was already enabled.
  def enable_multi_tenant!
    report = verify
    raise NotReady, "Teams are not fully assigned; run verify first" unless report[:ok]
    return false if report[:multi_tenant_enabled]

    @client.update_app_settings(multi_tenant_enabled: true)
    true
  end

  private

  def all_channels
    channels = []
    offset = 0

    loop do
      response = @client.query_channels(CHANNEL_FILTER, sort: SORT, limit: PAGE_SIZE, offset: offset)
      page = response["channels"].map { |entry| entry["channel"] }
      channels.concat(page)
      break if page.size < PAGE_SIZE

      offset += page.size
    end

    channels
  end

  def build_row(channel)
    resolved_team, source = resolve_team(channel)

    Row.new(
      type: channel["type"],
      id: channel["id"],
      current_team: channel["team"].presence,
      community_slug: channel["community_slug"].presence,
      resolved_team: resolved_team,
      source: source
    )
  end

  def resolve_team(channel)
    slug = channel["community_slug"].presence
    return [ slug, :community_slug ] if slug && community_slugs.include?(slug)

    # Longest slug first so "crow-woods-x" can't be claimed by a community "crow"
    prefix = community_slugs.find { |s| channel["id"].start_with?("#{s}-") }
    return [ prefix, :id_prefix ] if prefix

    return [ @legacy_slug, :legacy ] if @legacy_slug && legacy_channel_ids.include?(channel["id"])

    [ nil, nil ]
  end

  def community_slugs
    @community_slugs ||= Community.pluck(:slug).sort_by { |s| -s.length }
  end

  def legacy_channel_ids
    @legacy_channel_ids ||= StreamChannelService::DEFAULT_CHANNELS.map { |c| c[:id] }
  end

  # Checks every user we know about against Stream, per community. A user who
  # is missing from Stream entirely also counts: they'd have no team after the
  # toggle either way.
  def find_users_without_teams
    missing = []

    Community.find_each do |community|
      ids = ActsAsTenant.with_tenant(community) { User.order(:id).pluck(:id).map(&:to_s) }

      ids.each_slice(PAGE_SIZE) do |batch|
        response = @client.query_users({ "id" => { "$in" => batch } }, limit: PAGE_SIZE)
        found = response["users"].index_by { |u| u["id"] }

        batch.each do |id|
          user = found[id]
          missing << id unless user && Array(user["teams"]).include?(community.slug)
        end
      end
    end

    missing
  end
end
