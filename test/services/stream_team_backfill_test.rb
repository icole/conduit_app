# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class StreamTeamBackfillTest < ActiveSupport::TestCase
  setup do
    @crow_woods = communities(:crow_woods)
    @other = communities(:other_community)
  end

  # Builds a Stream query_channels response for one page of channels.
  def channels_page(*channels)
    { "channels" => channels.map { |c| { "channel" => c } } }
  end

  def channel(id, type: "team", team: nil, community_slug: nil)
    { "id" => id, "type" => type, "cid" => "#{type}:#{id}", "team" => team, "community_slug" => community_slug }.compact
  end

  def stub_channels(mock_client, *channels)
    mock_client.expect :query_channels, channels_page(*channels),
      [ StreamTeamBackfill::CHANNEL_FILTER ], sort: StreamTeamBackfill::SORT, limit: StreamTeamBackfill::PAGE_SIZE, offset: 0
    return if channels.size < StreamTeamBackfill::PAGE_SIZE

    mock_client.expect :query_channels, channels_page,
      [ StreamTeamBackfill::CHANNEL_FILTER ], sort: StreamTeamBackfill::SORT, limit: StreamTeamBackfill::PAGE_SIZE, offset: channels.size
  end

  test "plan resolves the team from community_slug, then id prefix, then legacy slug" do
    mock_client = Minitest::Mock.new
    stub_channels(mock_client,
      channel("crow-woods-general", community_slug: "crow-woods"),
      channel("other-community-pets-123"),
      channel("general"),
      channel("mystery-channel"))

    plan = StreamTeamBackfill.new(client: mock_client, legacy_slug: "crow-woods").plan

    assert_equal %w[crow-woods-general other-community-pets-123 general mystery-channel], plan.map(&:id)
    assert_equal [ "crow-woods", "other-community", "crow-woods", nil ], plan.map(&:resolved_team)
    assert_equal [ :community_slug, :id_prefix, :legacy, nil ], plan.map(&:source)
    mock_client.verify
  end

  test "plan marks channels whose team already matches as unchanged" do
    mock_client = Minitest::Mock.new
    stub_channels(mock_client, channel("crow-woods-general", team: "crow-woods", community_slug: "crow-woods"))

    row = StreamTeamBackfill.new(client: mock_client).plan.first

    assert_equal "crow-woods", row.current_team
    assert_not row.changed?
    mock_client.verify
  end

  test "apply! refuses to run while any channel is unattributed" do
    mock_client = Minitest::Mock.new
    stub_channels(mock_client, channel("mystery-channel"))

    assert_raises StreamTeamBackfill::UnattributedChannels do
      StreamTeamBackfill.new(client: mock_client).apply!
    end
    mock_client.verify
  end

  test "apply! sets team only on channels that need it" do
    mock_client = Minitest::Mock.new
    stub_channels(mock_client,
      channel("crow-woods-general", team: "crow-woods", community_slug: "crow-woods"),
      channel("other-community-pets-123"))

    mock_channel = Minitest::Mock.new
    mock_channel.expect :update_partial, {}, [ { "team" => "other-community" } ]
    mock_client.expect :channel, mock_channel, [ "team" ], channel_id: "other-community-pets-123"

    applied = StreamTeamBackfill.new(client: mock_client).apply!

    assert_equal [ "other-community-pets-123" ], applied.map(&:id)
    mock_client.verify
    mock_channel.verify
  end

  test "verify reports channels without a team, mismatched channels, and users without teams" do
    mock_client = Minitest::Mock.new
    mock_client.expect :get_app_settings, { "app" => { "name" => "Conduit", "multi_tenant_enabled" => false } }
    stub_channels(mock_client,
      channel("crow-woods-general", team: "crow-woods", community_slug: "crow-woods"),
      channel("crow-woods-events", community_slug: "crow-woods"),
      channel("other-community-pets", team: "crow-woods", community_slug: "other-community"))

    # Users are checked per community, in batches, straight from our DB.
    Community.find_each do |community|
      ids = ActsAsTenant.with_tenant(community) { User.order(:id).pluck(:id).map(&:to_s) }
      next if ids.empty?

      users = ids.map do |id|
        # Leave the community's first user without teams to exercise the report.
        { "id" => id, "teams" => (id == ids.first ? [] : [ community.slug ]) }
      end
      mock_client.expect :query_users, { "users" => users }, [ { "id" => { "$in" => ids } } ], limit: StreamTeamBackfill::PAGE_SIZE
    end

    report = StreamTeamBackfill.new(client: mock_client).verify

    assert_equal [ "crow-woods-events" ], report[:channels_without_team]
    assert_equal [ "other-community-pets" ], report[:channels_mismatched]
    communities_with_users = Community.all.count { |c| ActsAsTenant.with_tenant(c) { User.exists? } }
    assert_equal communities_with_users, report[:users_without_teams].size
    assert_not report[:ok]
    mock_client.verify
  end

  # --- multi-tenant app state ---

  def stub_app_settings(mock_client, multi_tenant:, name: "Conduit Prod")
    mock_client.expect :get_app_settings, { "app" => { "name" => name, "multi_tenant_enabled" => multi_tenant } }
  end

  def stub_all_users_with_teams(mock_client)
    Community.find_each do |community|
      ids = ActsAsTenant.with_tenant(community) { User.order(:id).pluck(:id).map(&:to_s) }
      next if ids.empty?

      users = ids.map { |id| { "id" => id, "teams" => [ community.slug ] } }
      mock_client.expect :query_users, { "users" => users }, [ { "id" => { "$in" => ids } } ], limit: StreamTeamBackfill::PAGE_SIZE
    end
  end

  test "app_info reports the app name and whether multi-tenant mode is enabled" do
    mock_client = Minitest::Mock.new
    stub_app_settings(mock_client, multi_tenant: false, name: "Conduit Dev")

    info = StreamTeamBackfill.new(client: mock_client).app_info

    assert_equal "Conduit Dev", info[:name]
    assert_equal false, info[:multi_tenant_enabled]
    mock_client.verify
  end

  test "verify includes the multi-tenant state and is ok when everything is assigned" do
    mock_client = Minitest::Mock.new
    stub_app_settings(mock_client, multi_tenant: true)
    stub_channels(mock_client, channel("crow-woods-general", team: "crow-woods", community_slug: "crow-woods"))
    stub_all_users_with_teams(mock_client)

    report = StreamTeamBackfill.new(client: mock_client).verify

    assert report[:ok]
    assert_equal true, report[:multi_tenant_enabled]
    mock_client.verify
  end

  test "enable_multi_tenant! refuses while verify is not ok" do
    mock_client = Minitest::Mock.new
    stub_app_settings(mock_client, multi_tenant: false)
    stub_channels(mock_client, channel("crow-woods-events", community_slug: "crow-woods"))
    stub_all_users_with_teams(mock_client)

    assert_raises StreamTeamBackfill::NotReady do
      StreamTeamBackfill.new(client: mock_client).enable_multi_tenant!
    end
    mock_client.verify
  end

  test "enable_multi_tenant! flips the app setting once verify is ok" do
    mock_client = Minitest::Mock.new
    stub_app_settings(mock_client, multi_tenant: false)
    stub_channels(mock_client, channel("crow-woods-general", team: "crow-woods", community_slug: "crow-woods"))
    stub_all_users_with_teams(mock_client)
    mock_client.expect :update_app_settings, {}, [], multi_tenant_enabled: true

    StreamTeamBackfill.new(client: mock_client).enable_multi_tenant!

    mock_client.verify
  end

  test "enable_multi_tenant! is a no-op when already enabled" do
    mock_client = Minitest::Mock.new
    stub_app_settings(mock_client, multi_tenant: true)
    stub_channels(mock_client, channel("crow-woods-general", team: "crow-woods", community_slug: "crow-woods"))
    stub_all_users_with_teams(mock_client)

    assert_equal false, StreamTeamBackfill.new(client: mock_client).enable_multi_tenant!
    mock_client.verify
  end
end
