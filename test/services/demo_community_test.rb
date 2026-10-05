require "test_helper"
require "minitest/mock"
require_relative "../support/fake_stream_client"

# The community App Store and Play reviewers sign in to (CON-66)
class DemoCommunityTest < ActiveSupport::TestCase
  # Generated, so no credential-shaped string sits in this public repo
  PASSWORD = SecureRandom.base58(20)

  setup do
    ActsAsTenant.current_tenant = nil
    @stream = FakeStreamClient.new
  end

  # The demo posts in chat, so it always runs against the fake Stream client
  def with_stream(&) = StreamChatClient.stub(:configured?, true) { StreamChatClient.stub(:client, @stream, &) }
  def ensure_demo! = with_stream { DemoCommunity.new(password: PASSWORD).ensure! }
  def reset_demo! = with_stream { DemoCommunity.new(password: PASSWORD).reset! }
  def community = Community.find_by!(slug: DemoCommunity::SLUG)
  def in_demo(&) = ActsAsTenant.with_tenant(community, &)
  def reviewer = in_demo { User.find_by!(email: DemoCommunity::EMAIL) }

  test "sets up an active community with chat on, the reviewer's account, and neighbours who use it" do
    ensure_demo!

    assert community.active?
    assert community.chat_enabled?
    assert reviewer.authenticate(PASSWORD)
    assert reviewer.email_verified?, "unverified members can't use chat"
    in_demo do
      assert_operator User.count, :>, 1
      meal = Meal.upcoming.first
      assert meal.head_cook
      assert_operator meal.meal_rsvps.count, :>=, 2
      assert Task.open.assigned_to(reviewer).exists?
    end
  end

  test "needs a password: there's no default, since this repo is public" do
    assert_raises(ArgumentError) { DemoCommunity.new(password: "") }
    assert_raises(ArgumentError) { DemoCommunity.new(password: nil) }
  end

  test "a reset clears what reviewers added and puts the sample content back, keeping their account" do
    ensure_demo!
    reviewer_id = reviewer.id
    in_demo do
      User.create!(name: "Invited Tester", email: "tester@example.com", password: "password123")
      Decision.create!(title: "Paint the common house")
      Meal.upcoming.first.destroy!
      MealRsvp.create!(meal: Meal.upcoming.first, user: reviewer, status: "attending")
    end

    reset_demo!

    assert_equal reviewer_id, reviewer.id
    assert reviewer.authenticate(PASSWORD)
    in_demo do
      assert_not User.exists?(email: "tester@example.com")
      assert_not Decision.exists?
      assert_equal 3, Meal.upcoming.count
      assert_not MealRsvp.exists?(user: reviewer)
      assert Task.open.assigned_to(reviewer).exists?
    end
  end

  test "a reset leaves every other community alone" do
    ensure_demo!
    others = ActsAsTenant.without_tenant do
      [ User, Meal, Task, Decision ].to_h { |model| [ model, model.where.not(community: community).count ] }
    end

    reset_demo!

    ActsAsTenant.without_tenant do
      others.each { |model, count| assert_equal count, model.where.not(community: community).count, model.name }
    end
  end

  test "won't touch a community that isn't the demo" do
    assert_raises(ArgumentError) { DemoCommunity.new(password: PASSWORD, slug: "crow-woods") }
  end

  test "neighbours start the conversation in General, after clearing last week's" do
    reset_demo!

    assert_includes @stream.truncated, "team:demo-general"
    assert_operator @stream.messages.count { |m| m[:channel] == "team:demo-general" }, :>=, 3
  end

  test "resets weekly, early Sunday Pacific" do
    recurring = YAML.load(ERB.new(Rails.root.join("config/recurring.yml").read).result, aliases: true)
    entry = recurring.dig("production", "demo_reset")
    assert_equal "DemoResetJob", entry["class"]
    assert_equal "0 3 * * 0 America/Los_Angeles", entry["schedule"]
  end

  test "the weekly job resets the demo with the password from the environment, and skips where there's none" do
    reset = Minitest::Mock.new
    reset.expect(:reset!, nil)
    configured = SecureRandom.base58(20)
    DemoCommunity.stub(:new, ->(password:) { assert_equal configured, password; reset }) do
      with_env("DEMO_USER_PASSWORD" => configured) { DemoResetJob.perform_now }
    end
    reset.verify

    DemoCommunity.stub(:new, ->(**) { flunk "no password, no reset" }) do
      with_env("DEMO_USER_PASSWORD" => nil) { DemoResetJob.perform_now }
    end
  end

  private

  def with_env(values)
    original = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
