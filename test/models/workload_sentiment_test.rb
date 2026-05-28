require "test_helper"

class WorkloadSentimentTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @role = roles(:garden_maven)
  end

  test "should require user" do
    sentiment = WorkloadSentiment.new(role: @role, sentiment: "just_right", month: Date.current.beginning_of_month)
    assert_not sentiment.valid?
    assert_includes sentiment.errors[:user], "must exist"
  end

  test "should require role" do
    sentiment = WorkloadSentiment.new(user: @user, sentiment: "just_right", month: Date.current.beginning_of_month)
    assert_not sentiment.valid?
    assert_includes sentiment.errors[:role], "must exist"
  end

  test "should require sentiment" do
    sentiment = WorkloadSentiment.new(user: @user, role: @role, month: Date.current.beginning_of_month)
    assert_not sentiment.valid?
    assert_includes sentiment.errors[:sentiment], "can't be blank"
  end

  test "should validate sentiment inclusion" do
    sentiment = WorkloadSentiment.new(user: @user, role: @role, sentiment: "confused", month: Date.current.beginning_of_month)
    assert_not sentiment.valid?
    assert_includes sentiment.errors[:sentiment], "is not included in the list"
  end

  test "should allow valid sentiment" do
    sentiment = WorkloadSentiment.new(
      user: @user,
      role: @role,
      sentiment: "just_right",
      month: Date.current.beginning_of_month
    )
    assert sentiment.valid?
  end

  test "should enforce one sentiment per user per role per month" do
    WorkloadSentiment.create!(user: @user, role: @role, sentiment: "just_right", month: Date.current.beginning_of_month)
    duplicate = WorkloadSentiment.new(user: @user, role: @role, sentiment: "too_much", month: Date.current.beginning_of_month)
    assert_not duplicate.valid?
  end
end
