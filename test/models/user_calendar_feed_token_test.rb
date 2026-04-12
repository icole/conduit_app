# frozen_string_literal: true

require "test_helper"

class UserCalendarFeedTokenTest < ActiveSupport::TestCase
  test "generate_calendar_feed_token! creates a token" do
    user = users(:one)
    user.update_column(:calendar_feed_token, nil)

    assert_nil user.calendar_feed_token

    user.generate_calendar_feed_token!

    assert_not_nil user.calendar_feed_token
    assert user.calendar_feed_token.length >= 20
  end

  test "generate_calendar_feed_token! does not overwrite existing token" do
    user = users(:one)
    user.update_column(:calendar_feed_token, "existing_token")

    user.generate_calendar_feed_token!

    assert_equal "existing_token", user.calendar_feed_token
  end

  test "calendar_feed_url returns the feed URL" do
    user = users(:one)
    user.update_column(:calendar_feed_token, "my_token_123")

    url = user.calendar_feed_url
    assert_includes url, "my_token_123"
    assert_includes url, ".ics"
  end
end
