# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class StreamIsolationAuditTest < ActiveSupport::TestCase
  setup do
    @crow_woods = communities(:crow_woods)
    @other = communities(:other_community)
    # Give the other community a user so both sides of the boundary are probed.
    @other_user = ActsAsTenant.with_tenant(@other) do
      User.create!(name: "Other Person", email: "other@example.com", password: "password123")
    end
    @crow_user = ActsAsTenant.with_tenant(@crow_woods) { User.order(:id).first }
  end

  # A fake client-side Stream API. `visible` maps a user token to the channels
  # Stream returns for an unfiltered queryChannels; `readable` maps a token to
  # the channel ids a direct query succeeds on.
  class FakeClientApi
    def initialize(visible:, readable:)
      @visible = visible
      @readable = readable
    end

    def query_channels(token:, filter:, offset:)
      channels = offset.zero? ? @visible.fetch(token, []) : []
      [ 200, { "channels" => channels.map { |c| { "channel" => c } } } ]
    end

    def query_channel(token:, type:, id:)
      @readable.fetch(token, []).include?(id) ? [ 200, { "channel" => { "id" => id } } ] : [ 403, { "message" => "not allowed" } ]
    end
  end

  def channel(id, slug, team: slug)
    { "id" => id, "type" => "team", "community_slug" => slug, "team" => team }.compact
  end

  # Fake server-side (API secret) client: lists every channel and mints
  # per-user tokens. Order-independent, since Community.find_each order
  # depends on fixture ids.
  class FakeServerClient
    def initialize(all_channels, tokens)
      @all_channels = all_channels
      @tokens = tokens
    end

    def query_channels(_filter, sort:, limit:, offset:)
      channels = offset.zero? ? @all_channels : []
      { "channels" => channels.map { |c| { "channel" => c } } }
    end

    def create_token(user_id)
      @tokens.fetch(user_id)
    end

    def verify = true
  end

  def server_client(all_channels)
    FakeServerClient.new(all_channels, { @crow_user.id.to_s => "tok-crow", @other_user.id.to_s => "tok-other" })
  end

  test "reports a leak when a user can see or read another community's channel" do
    crow_general = channel("crow-woods-general", "crow-woods")
    other_general = channel("other-community-general", "other-community")
    client = server_client([ crow_general, other_general ])

    api = FakeClientApi.new(
      visible: { "tok-crow" => [ crow_general, other_general ], "tok-other" => [ other_general ] },
      readable: { "tok-crow" => [ "crow-woods-general", "other-community-general" ], "tok-other" => [ "other-community-general" ] }
    )

    report = StreamIsolationAudit.new(client: client, api: api).run

    assert report[:leaks]
    crow = report[:communities].fetch("crow-woods")
    assert_equal [ "other-community-general" ], crow[:foreign_visible]
    assert_equal [ "other-community-general" ], crow[:foreign_readable]

    other = report[:communities].fetch("other-community")
    assert_empty other[:foreign_visible]
    assert_empty other[:foreign_readable]
    client.verify
  end

  test "is clean when every user only sees and reads their own community's channels" do
    crow_general = channel("crow-woods-general", "crow-woods")
    other_general = channel("other-community-general", "other-community")
    client = server_client([ crow_general, other_general ])

    api = FakeClientApi.new(
      visible: { "tok-crow" => [ crow_general ], "tok-other" => [ other_general ] },
      readable: { "tok-crow" => [ "crow-woods-general" ], "tok-other" => [ "other-community-general" ] }
    )

    report = StreamIsolationAudit.new(client: client, api: api).run

    assert_not report[:leaks]
    assert_equal 1, report[:communities].fetch("crow-woods")[:visible_count]
    assert_equal 1, report[:communities].fetch("crow-woods")[:probed_count]
    client.verify
  end

  test "counts a visible channel with no community attribution as a leak" do
    crow_general = channel("crow-woods-general", "crow-woods")
    orphan = { "id" => "mystery", "type" => "team" }
    client = server_client([ crow_general, orphan ])

    api = FakeClientApi.new(
      visible: { "tok-crow" => [ crow_general, orphan ], "tok-other" => [] },
      readable: { "tok-crow" => [ "crow-woods-general" ], "tok-other" => [] }
    )

    report = StreamIsolationAudit.new(client: client, api: api).run

    assert report[:leaks]
    assert_equal [ "mystery" ], report[:communities].fetch("crow-woods")[:unattributed_visible]
    client.verify
  end
end
