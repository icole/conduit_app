# frozen_string_literal: true

require "test_helper"

class CommunityStatusTest < ActiveSupport::TestCase
  test "a new community starts pending" do
    community = Community.new(name: "New", slug: "new", domain: "new.test")
    assert community.pending?
    assert_not community.active?
  end

  test "status only accepts pending, active or suspended" do
    assert_raises(ArgumentError) { Community.new(status: "bogus") }
  end

  test "approve! makes a pending community active" do
    community = communities(:pending_community)
    community.approve!
    assert community.reload.active?
  end

  test "suspend! makes a community suspended and revokes every member's mobile tokens" do
    community = communities(:crow_woods)
    users = ActsAsTenant.with_tenant(community) { User.order(:id).to_a }
    versions_before = users.map(&:token_version)

    community.suspend!

    assert community.reload.suspended?
    users.each(&:reload)
    assert_equal versions_before.map { |v| v + 1 }, users.map(&:token_version)
  end

  test "active scope excludes pending and suspended communities" do
    slugs = Community.active.pluck(:slug)
    assert_includes slugs, "crow-woods"
    assert_not_includes slugs, "pending-community"
    assert_not_includes slugs, "suspended-community"
  end

  test "chat_available? is only true for active communities" do
    assert communities(:crow_woods).chat_available?
    assert_not communities(:pending_community).chat_available?
    assert_not communities(:suspended_community).chat_available?
  end
end
