# frozen_string_literal: true

# Proves (or disproves) that Stream channels can't be reached across community
# boundaries, by doing what an attacker with a valid token would do: for one
# real user per community, call Stream's *client-side* API with that user's
# token - no app, no filter - and see what comes back.
#
# Two probes per community:
#   1. queryChannels with only a type filter (what the app would see if it
#      dropped its "members ∋ me" filter). Anything not belonging to the user's
#      community is a leak.
#   2. A direct query of every other community's channels. A 2xx is a leak.
#
# Server-side calls (API secret) bypass permissions entirely, so this
# deliberately talks to Stream over HTTP with the user token instead.
class StreamIsolationAudit
  CLIENT_FILTER = { "type" => { "$eq" => "team" } }.freeze
  PAGE_SIZE = 30

  # Minimal client-side Stream API. Returns [status, parsed_body].
  class ClientApi
    def initialize(api_key: StreamChatClient.api_key, base_url: ENV.fetch("STREAM_CHAT_URL", "https://chat.stream-io-api.com"))
      @api_key = api_key
      @base_url = base_url
    end

    def query_channels(token:, filter:, offset:)
      post("/channels", token, {
        filter_conditions: filter,
        sort: [ { field: "created_at", direction: -1 } ],
        limit: PAGE_SIZE,
        offset: offset,
        state: false,
        watch: false,
        presence: false
      })
    end

    def query_channel(token:, type:, id:)
      post("/channels/#{type}/#{id}/query", token, { state: false, watch: false, presence: false })
    end

    private

    def post(path, token, body)
      uri = URI("#{@base_url}#{path}?api_key=#{@api_key}")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = token
      request["Stream-Auth-Type"] = "jwt"
      request["Content-Type"] = "application/json"
      request.body = body.to_json

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      [ response.code.to_i, (JSON.parse(response.body) rescue {}) ]
    end
  end

  def initialize(client: StreamChatClient.client, api: ClientApi.new)
    @client = client
    @api = api
  end

  # => { leaks: bool, communities: { slug => { user_id:, visible_count:, foreign_visible:,
  #      unattributed_visible:, probed_count:, foreign_readable: } } }
  def run
    channels_by_slug = all_channels.group_by { |c| owner_slug(c) }
    results = {}

    Community.find_each do |community|
      user = ActsAsTenant.with_tenant(community) { User.order(:id).first }
      next unless user

      token = @client.create_token(user.id.to_s)
      visible = visible_channels(token)
      foreign_ids = channels_by_slug.except(community.slug, nil).values.flatten.map { |c| c["id"] }

      results[community.slug] = {
        user_id: user.id,
        visible_count: visible.size,
        foreign_visible: visible.select { |c| owner_slug(c).present? && owner_slug(c) != community.slug }.map { |c| c["id"] },
        unattributed_visible: visible.select { |c| owner_slug(c).nil? }.map { |c| c["id"] },
        probed_count: foreign_ids.size,
        foreign_readable: foreign_ids.select { |id| readable?(token, id) }
      }
    end

    leaks = results.values.any? { |r| r[:foreign_visible].any? || r[:unattributed_visible].any? || r[:foreign_readable].any? }
    { leaks: leaks, communities: results }
  end

  private

  # Which community a channel belongs to, by the same rules the backfill uses:
  # team, then community_slug, then id prefix.
  def owner_slug(channel)
    channel["team"].presence || channel["community_slug"].presence ||
      community_slugs.find { |s| channel["id"].to_s.start_with?("#{s}-") }
  end

  def community_slugs
    @community_slugs ||= Community.pluck(:slug).sort_by { |s| -s.length }
  end

  def visible_channels(token)
    channels = []
    offset = 0

    loop do
      status, body = @api.query_channels(token: token, filter: CLIENT_FILTER, offset: offset)
      break unless status.between?(200, 299)

      page = (body["channels"] || []).map { |entry| entry["channel"] }
      channels.concat(page)
      break if page.size < PAGE_SIZE

      offset += page.size
    end

    channels
  end

  def readable?(token, channel_id)
    status, _body = @api.query_channel(token: token, type: "team", id: channel_id)
    status.between?(200, 299)
  end

  # Server-side, secret-authenticated listing of every channel, used only to
  # know what exists so we can probe it as each user.
  def all_channels
    channels = []
    offset = 0

    loop do
      response = @client.query_channels(StreamTeamBackfill::CHANNEL_FILTER, sort: StreamTeamBackfill::SORT,
                                        limit: StreamTeamBackfill::PAGE_SIZE, offset: offset)
      page = response["channels"].map { |entry| entry["channel"] }
      channels.concat(page)
      break if page.size < StreamTeamBackfill::PAGE_SIZE

      offset += page.size
    end

    channels
  end
end
