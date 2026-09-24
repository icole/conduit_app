# frozen_string_literal: true

require "test_helper"

class StreamUsageReportTest < ActiveSupport::TestCase
  setup do
    @crow_woods = communities(:crow_woods)
    @other = communities(:other_community)
    # Start from a clean slate: fixtures don't set chat access.
    ActsAsTenant.without_tenant { User.unscoped.update_all(last_chat_token_at: nil) }
  end

  def touch_chat(user, at:)
    ActsAsTenant.without_tenant { User.unscoped.where(id: user.id).update_all(last_chat_token_at: at) }
  end

  test "counts only users who used chat in the current calendar month" do
    users = ActsAsTenant.with_tenant(@crow_woods) { User.order(:id).limit(3).to_a }
    touch_chat users[0], at: Time.current
    touch_chat users[1], at: Time.current.beginning_of_month
    touch_chat users[2], at: Time.current.beginning_of_month - 1.day # last month

    report = StreamUsageReport.new(limit: 1000).call

    assert_equal 2, report[:total]
    assert_equal 2, report[:by_community][@crow_woods.slug]
  end

  test "reports each community separately and omits communities with no chat use" do
    crow_user = ActsAsTenant.with_tenant(@crow_woods) { User.order(:id).first }
    other_user = ActsAsTenant.with_tenant(@other) { User.order(:id).first }
    touch_chat crow_user, at: Time.current
    touch_chat other_user, at: Time.current

    report = StreamUsageReport.new(limit: 1000).call

    assert_equal 1, report[:by_community][@crow_woods.slug]
    assert_equal 1, report[:by_community][@other.slug]
    assert_not report[:by_community].key?("pending-community")
  end

  test "reports usage as a percentage of the plan limit" do
    user = ActsAsTenant.with_tenant(@crow_woods) { User.order(:id).first }
    touch_chat user, at: Time.current

    report = StreamUsageReport.new(limit: 4).call

    assert_equal 4, report[:limit]
    assert_equal 25, report[:percent_used]
  end

  test "names the highest threshold reached, or nil below them all" do
    users = ActsAsTenant.with_tenant(@crow_woods) { User.order(:id).limit(10).to_a }

    touch_chat users[0], at: Time.current
    assert_nil StreamUsageReport.new(limit: 10).call[:threshold]

    users.first(7).each { |u| touch_chat u, at: Time.current }
    assert_equal 70, StreamUsageReport.new(limit: 10).call[:threshold]

    users.first(9).each { |u| touch_chat u, at: Time.current }
    assert_equal 90, StreamUsageReport.new(limit: 10).call[:threshold]
  end

  test "a zero or missing limit means no threshold and no percentage" do
    touch_chat ActsAsTenant.with_tenant(@crow_woods) { User.order(:id).first }, at: Time.current

    report = StreamUsageReport.new(limit: 0).call

    assert_nil report[:threshold]
    assert_nil report[:percent_used]
    assert_equal 1, report[:total]
  end
end
