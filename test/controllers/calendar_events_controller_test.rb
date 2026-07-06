# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class CalendarEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_user({ uid: @user.uid, name: @user.name, email: @user.email })

    @mock_event = {
      id: "test_event_abc123",
      summary: "Community Meeting",
      description: "Monthly check-in",
      location: "Common House",
      start_time: 1.day.from_now.change(hour: 18, min: 0),
      end_time: 1.day.from_now.change(hour: 19, min: 0),
      all_day: false,
      html_link: "https://calendar.google.com/event?eid=test",
      creator: "test@example.com",
      status: "confirmed"
    }

    @mock_service = Minitest::Mock.new

    @start_date = 1.day.from_now.strftime("%Y-%m-%d")
    @end_date = @start_date
  end

  test "should get new" do
    get new_calendar_event_url
    assert_response :success
    assert_select "h1", "New Calendar Event"
  end

  test "should create event on google calendar" do
    @mock_service.expect(:create_event, { status: :success, event_id: "new_event_123", html_link: "https://..." },
      calendar_id: ENV["GOOGLE_CALENDAR_ID"],
      title: "Community Meeting",
      start_time: ->(t) { t.is_a?(Time) || t.is_a?(ActiveSupport::TimeWithZone) },
      end_time: ->(t) { t.is_a?(Time) || t.is_a?(ActiveSupport::TimeWithZone) },
      description: "Monthly check-in",
      location: "Common House")

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      post calendar_events_url, params: {
        calendar_event: {
          title: "Community Meeting",
          description: "Monthly check-in",
          start_date: @start_date,
          start_time_of_day: "18:00",
          end_date: @end_date,
          end_time_of_day: "19:00",
          location: "Common House"
        }
      }
    end

    assert_redirected_to calendar_event_url(google_event_id: "new_event_123")
    @mock_service.verify
  end

  test "create shows error when google api fails" do
    @mock_service.expect(:create_event, { status: :client_error, error: "Calendar not found" },
      calendar_id: ENV["GOOGLE_CALENDAR_ID"],
      title: "Test",
      start_time: ->(t) { t.is_a?(Time) || t.is_a?(ActiveSupport::TimeWithZone) },
      end_time: ->(t) { t.is_a?(Time) || t.is_a?(ActiveSupport::TimeWithZone) },
      description: "",
      location: "")

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      post calendar_events_url, params: {
        calendar_event: {
          title: "Test",
          description: "",
          start_date: @start_date,
          start_time_of_day: "18:00",
          end_date: @end_date,
          end_time_of_day: "19:00",
          location: ""
        }
      }
    end

    assert_response :unprocessable_entity
    @mock_service.verify
  end

  test "create shows error when datetime fields are missing" do
    post calendar_events_url, params: {
      calendar_event: {
        title: "Test",
        start_date: "",
        start_time_of_day: "",
        end_date: "",
        end_time_of_day: ""
      }
    }

    assert_response :unprocessable_entity
  end

  test "should show event from google calendar" do
    @mock_service.expect(:get_event, @mock_event, [ ENV["GOOGLE_CALENDAR_ID"], "test_event_abc123" ])

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      get calendar_event_url(google_event_id: "test_event_abc123")
    end

    assert_response :success
    assert_select "h1", "Community Meeting"
    @mock_service.verify
  end

  test "show redirects when event not found" do
    @mock_service.expect(:get_event, { error: "not found", status: :client_error }, [ ENV["GOOGLE_CALENDAR_ID"], "bad_id" ])

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      get calendar_event_url(google_event_id: "bad_id")
    end

    assert_redirected_to calendar_index_url
    @mock_service.verify
  end

  test "should get edit with event data" do
    @mock_service.expect(:get_event, @mock_event, [ ENV["GOOGLE_CALENDAR_ID"], "test_event_abc123" ])

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      get edit_calendar_event_url(google_event_id: "test_event_abc123")
    end

    assert_response :success
    @mock_service.verify
  end

  test "should update event on google calendar" do
    @mock_service.expect(:update_event, { status: :success, event_id: "test_event_abc123" },
      calendar_id: ENV["GOOGLE_CALENDAR_ID"],
      event_id: "test_event_abc123",
      title: "Updated Title",
      start_time: ->(t) { t.is_a?(Time) || t.is_a?(ActiveSupport::TimeWithZone) },
      end_time: ->(t) { t.is_a?(Time) || t.is_a?(ActiveSupport::TimeWithZone) },
      description: "Updated desc",
      location: "New Location")

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      patch calendar_event_url(google_event_id: "test_event_abc123"), params: {
        calendar_event: {
          title: "Updated Title",
          description: "Updated desc",
          start_date: @start_date,
          start_time_of_day: "18:00",
          end_date: @end_date,
          end_time_of_day: "19:00",
          location: "New Location"
        }
      }
    end

    assert_redirected_to calendar_event_url(google_event_id: "test_event_abc123")
    @mock_service.verify
  end

  test "should destroy event on google calendar" do
    @mock_service.expect(:delete_event, { status: :success },
      calendar_id: ENV["GOOGLE_CALENDAR_ID"],
      event_id: "test_event_abc123")

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      delete calendar_event_url(google_event_id: "test_event_abc123")
    end

    assert_redirected_to calendar_index_url
    @mock_service.verify
  end

  test "destroy redirects with error flash when google api fails" do
    @mock_service.expect(:delete_event, { status: :client_error, error: "Permission denied" },
      calendar_id: ENV["GOOGLE_CALENDAR_ID"],
      event_id: "test_event_abc123")

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      delete calendar_event_url(google_event_id: "test_event_abc123")
    end

    assert_redirected_to calendar_index_url
    assert_equal "Failed to delete event: Permission denied", flash[:alert]
    @mock_service.verify
  end

  test "update re-renders edit with event populated when google api fails" do
    @mock_service.expect(:update_event, { status: :client_error, error: "API quota exceeded" },
      calendar_id: ENV["GOOGLE_CALENDAR_ID"],
      event_id: "test_event_abc123",
      title: "Updated Title",
      start_time: ->(t) { t.is_a?(Time) || t.is_a?(ActiveSupport::TimeWithZone) },
      end_time: ->(t) { t.is_a?(Time) || t.is_a?(ActiveSupport::TimeWithZone) },
      description: "Updated desc",
      location: "New Location")

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      patch calendar_event_url(google_event_id: "test_event_abc123"), params: {
        calendar_event: {
          title: "Updated Title",
          description: "Updated desc",
          start_date: @start_date,
          start_time_of_day: "18:00",
          end_date: @end_date,
          end_time_of_day: "19:00",
          location: "New Location"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_equal "test_event_abc123", assigns(:event).google_event_id
    assert_equal "Updated Title", assigns(:event).title
    @mock_service.verify
  end
end
