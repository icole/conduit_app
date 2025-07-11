require "application_system_test_case"

class CalendarSharesTest < ApplicationSystemTestCase
  setup do
    # Use fixture user
    @user = users(:one)

    # Sign in the user
    sign_in_user
  end

  test "subscribe button is visible when user has no calendar share" do
    # Delete any existing calendar shares for this user
    CalendarShare.where(user_id: @user.id).destroy_all

    visit root_path

    # The subscribe button should be visible
    assert_selector ".badge", text: "Subscribe"
  end

  test "subscribe button is hidden when user already has calendar share" do
    # Ensure the user has a calendar share
    calendar_id = ENV["GOOGLE_CALENDAR_ID"] || "test_calendar_id"
    CalendarShare.find_or_create_by(user_id: @user.id, calendar_id: calendar_id, shared_at: Time.current)

    visit root_path

    # The subscribe button should not be visible
    assert_no_selector ".badge", text: "Subscribe"
  end
end
