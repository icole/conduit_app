# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class CalendarFeedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(calendar_feed_token: "valid_test_token_123")
  end

  test "returns ICS content with valid token" do
    mock_events = {
      status: :success,
      events: [
        {
          id: "event1",
          summary: "Community Meal",
          description: "Weekly dinner",
          location: "Common House",
          start_time: Time.zone.parse("2026-04-15 18:30"),
          end_time: Time.zone.parse("2026-04-15 20:00"),
          all_day: false
        }
      ]
    }

    fake_service = Object.new
    fake_service.define_singleton_method(:get_events) { |**_args| mock_events }

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, fake_service) do
      get calendar_feed_url(token: "valid_test_token_123", format: :ics)
    end

    assert_response :success
    assert_equal "text/calendar; charset=utf-8", response.content_type
    assert_includes response.body, "BEGIN:VCALENDAR"
    assert_includes response.body, "Community Meal"
    assert_includes response.body, "Weekly dinner"
    assert_includes response.body, "Common House"
    assert_includes response.body, "END:VCALENDAR"
  end

  test "returns 404 with invalid token" do
    get calendar_feed_url(token: "invalid_token", format: :ics)

    assert_response :not_found
  end

  test "returns ICS with all-day events" do
    mock_events = {
      status: :success,
      events: [
        {
          id: "event2",
          summary: "Work Party",
          description: nil,
          location: nil,
          start_time: Time.zone.parse("2026-04-20"),
          end_time: Time.zone.parse("2026-04-21"),
          all_day: true
        }
      ]
    }

    fake_service = Object.new
    fake_service.define_singleton_method(:get_events) { |**_args| mock_events }

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, fake_service) do
      get calendar_feed_url(token: "valid_test_token_123", format: :ics)
    end

    assert_response :success
    assert_includes response.body, "Work Party"
  end
end
