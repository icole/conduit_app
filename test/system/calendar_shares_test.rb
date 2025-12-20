require "application_system_test_case"

class CalendarSharesTest < ApplicationSystemTestCase
  setup do
    # Use fixture user
    @user = users(:one)

    # Sign in as the fixture user (not a new OAuth user)
    sign_in_as(@user)
  end

  test "subscribe button is visible when user has no calendar share" do
    # Get the community's google_calendar_id from settings
    community = communities(:crow_woods)
    calendar_id = community.settings&.dig("google_calendar_id")

    # Skip this test if Google Calendar is not configured in community settings
    skip "Google Calendar not configured in community settings" unless calendar_id.present?

    # Delete any existing calendar shares for this user
    CalendarShare.where(user_id: @user.id).destroy_all

    visit root_path

    # The subscribe button should be visible
    assert_selector ".badge", text: "Subscribe"
  end

  test "subscribe button is hidden when user already has calendar share" do
    # Get the community's google_calendar_id from settings
    community = communities(:crow_woods)
    calendar_id = community.settings&.dig("google_calendar_id")

    # Skip this test if Google Calendar is not configured in community settings
    skip "Google Calendar not configured in community settings" unless calendar_id.present?

    # Ensure the user has a calendar share for the correct calendar_id
    CalendarShare.find_or_create_by(user_id: @user.id, calendar_id: calendar_id) do |share|
      share.shared_at = Time.current
    end

    visit root_path

    # The subscribe button should not be visible
    assert_no_selector ".badge", text: "Subscribe"
  end
end
