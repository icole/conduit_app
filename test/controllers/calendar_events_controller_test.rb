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

    # Back to the calendar, at the event's month, with its popup open
    assert_redirected_to calendar_index_url(start_date: @start_date)
    assert_equal "new_event_123", flash[:open_event_modal]
    @mock_service.verify
  end

  test "a one-day event ends on the day it starts, so the form only asks for one date" do
    @mock_service.expect(:create_event, { status: :success, event_id: "new_event_123" },
      calendar_id: ENV["GOOGLE_CALENDAR_ID"],
      title: "Potluck",
      start_time: ->(t) { t == Time.zone.parse("#{@start_date} 18:00") },
      end_time: ->(t) { t == Time.zone.parse("#{@start_date} 20:30") },
      description: "",
      location: "")

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      post calendar_events_url, params: { calendar_event: { title: "Potluck", start_date: @start_date,
                                                            start_time_of_day: "18:00", end_time_of_day: "20:30" } }
    end

    assert_redirected_to calendar_index_url(start_date: @start_date)
    @mock_service.verify
  end

  test "an end before the start is refused without calling Google" do
    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      post calendar_events_url, params: { calendar_event: { title: "Backwards", start_date: @start_date,
                                                            start_time_of_day: "19:00", end_time_of_day: "18:00" } }
    end

    assert_response :unprocessable_entity
    assert_match "The end needs to be after the start", response.body
    @mock_service.verify
  end

  test "a new event starts at the next full hour today, an hour long, on one day" do
    travel_to Time.zone.local(2026, 10, 1, 14, 20) do
      get new_calendar_event_url
    end

    assert_select "input[name='calendar_event[start_date]'][value='2026-10-01']"
    assert_select "input[name='calendar_event[start_time_of_day]'][value='15:00']"
    assert_select "input[name='calendar_event[end_time_of_day]'][value='16:00']"
    assert_select "input[type=checkbox][name='calendar_event[multi_day]']:not([checked])"
    assert_select "input[name='calendar_event[end_date]'][disabled]"
  end

  test "editing an event that runs over several days shows its end date" do
    @mock_event[:end_time] = 3.days.from_now.change(hour: 11, min: 0)
    @mock_service.expect(:get_event, @mock_event, [ ENV["GOOGLE_CALENDAR_ID"], "test_event_abc123" ])

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      get edit_calendar_event_url(google_event_id: "test_event_abc123")
    end

    assert_select "input[type=checkbox][name='calendar_event[multi_day]'][checked]"
    assert_select "input[name='calendar_event[end_date]'][value='#{3.days.from_now.strftime('%Y-%m-%d')}']:not([disabled])"
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

  test "an event's own page is gone: its link opens the event's popup on the calendar" do
    @mock_service.expect(:get_event, @mock_event, [ ENV["GOOGLE_CALENDAR_ID"], "test_event_abc123" ])

    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, @mock_service) do
      get calendar_event_url(google_event_id: "test_event_abc123")
    end

    assert_redirected_to calendar_index_url(start_date: @mock_event[:start_time].to_date.to_s)
    assert_equal "test_event_abc123", flash[:open_event_modal]
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

    assert_redirected_to calendar_index_url(start_date: @start_date)
    assert_equal "test_event_abc123", flash[:open_event_modal]
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
