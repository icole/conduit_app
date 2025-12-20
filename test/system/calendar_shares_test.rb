require "application_system_test_case"

class CalendarSharesTest < ApplicationSystemTestCase
  setup do
    # Use fixture user
    @user = users(:one)
    @community = communities(:crow_woods)
    @calendar_id = @community.settings&.dig("google_calendar_id")

    # Sign in as the fixture user (not a new OAuth user)
    sign_in_as(@user)

    # Set a dummy CALENDAR_CONFIG_FILE env var so CalendarCredentials.configured? returns true
    # This allows the Subscribe button to be shown in tests without real Google credentials
    @original_calendar_config = ENV["CALENDAR_CONFIG_FILE"]
    ENV["CALENDAR_CONFIG_FILE"] = "dummy_for_test"
  end

  teardown do
    # Restore original env var
    if @original_calendar_config
      ENV["CALENDAR_CONFIG_FILE"] = @original_calendar_config
    else
      ENV.delete("CALENDAR_CONFIG_FILE")
    end
  end

  test "subscribe button is visible when user has no calendar share" do
    # Skip if no calendar_id configured in community
    skip "No google_calendar_id in community settings" unless @calendar_id.present?

    # Delete any existing calendar shares for this user
    CalendarShare.where(user_id: @user.id).destroy_all

    visit root_path

    # The subscribe button should be visible
    assert_selector ".badge", text: "Subscribe"
  end

  test "subscribe button is hidden when user already has calendar share" do
    # Skip if no calendar_id configured in community
    skip "No google_calendar_id in community settings" unless @calendar_id.present?

    # Ensure the user has a calendar share for the correct calendar_id
    CalendarShare.find_or_create_by(user_id: @user.id, calendar_id: @calendar_id) do |share|
      share.shared_at = Time.current
    end

    visit root_path

    # The subscribe button should not be visible
    assert_no_selector ".badge", text: "Subscribe"
  end
end
