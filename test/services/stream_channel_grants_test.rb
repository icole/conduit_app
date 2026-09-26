# frozen_string_literal: true

require "test_helper"

class StreamChannelGrantsTest < ActiveSupport::TestCase
  # Stream's update_channel_type replaces the whole array for each role it is
  # given, and leaves unmentioned roles alone - so every change here is a
  # read-modify-write of one role.
  class FakeClient
    attr_reader :updates

    def initialize(grants)
      @grants = grants
      @updates = []
    end

    def get_channel_type(type)
      { "name" => type, "grants" => @grants }
    end

    def update_channel_type(type, **options)
      @updates << [ type, options ]
      {}
    end
  end

  DEFAULT_GRANTS = {
    "user" => [ "create-channel", "read-channel", "create-message" ],
    "channel_member" => [ "read-channel", "create-message" ],
    "admin" => [ "create-channel", "delete-channel" ]
  }.freeze

  setup do
    @client = FakeClient.new(DEFAULT_GRANTS.deep_dup)
    @grants = StreamChannelGrants.new(client: @client, channel_type: "team")
  end

  test "reads the grants for each role" do
    assert_equal DEFAULT_GRANTS["user"], @grants.for_role("user")
    assert_includes @grants.roles, "channel_member"
  end

  test "plan shows what a revoke would change without writing" do
    plan = @grants.plan_revoke(role: "user", permission: "create-channel")

    assert plan[:changed]
    assert_equal DEFAULT_GRANTS["user"], plan[:before]
    assert_equal [ "read-channel", "create-message" ], plan[:after]
    assert_empty @client.updates
  end

  test "plan reports no change when the permission is not granted" do
    plan = @grants.plan_revoke(role: "user", permission: "delete-channel")

    assert_not plan[:changed]
    assert_equal plan[:before], plan[:after]
  end

  test "revoke sends only the affected role, with the full remaining list" do
    @grants.revoke!(role: "user", permission: "create-channel")

    assert_equal 1, @client.updates.size
    type, options = @client.updates.first
    assert_equal "team", type
    assert_equal({ "user" => [ "read-channel", "create-message" ] }, options[:grants])
    assert_not options[:grants].key?("admin"), "must not touch other roles"
  end

  test "revoke is a no-op when the permission is already absent" do
    assert_not @grants.revoke!(role: "user", permission: "delete-channel")
    assert_empty @client.updates
  end

  test "an unknown role is refused rather than silently creating one" do
    assert_raises StreamChannelGrants::UnknownRole do
      @grants.plan_revoke(role: "moderators", permission: "create-channel")
    end
  end

  test "grant adds a permission back, for undoing a revoke" do
    @grants.grant!(role: "user", permission: "delete-channel")

    _type, options = @client.updates.first
    assert_equal [ "create-channel", "read-channel", "create-message", "delete-channel" ], options[:grants]["user"]
  end

  test "grant is a no-op when the permission is already there" do
    assert_not @grants.grant!(role: "user", permission: "read-channel")
    assert_empty @client.updates
  end
end
