# frozen_string_literal: true

require "application_system_test_case"

class CalendarPageTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @community = communities(:crow_woods)
    @calendar_id = @community.settings&.dig("google_calendar_id")

    sign_in_as(@user)

    # Set dummy env var so CalendarCredentials.configured? returns true
    @original_calendar_config = ENV["CALENDAR_CONFIG_FILE"]
    ENV["CALENDAR_CONFIG_FILE"] = "dummy_for_test"
  end

  teardown do
    if @original_calendar_config
      ENV["CALENDAR_CONFIG_FILE"] = @original_calendar_config
    else
      ENV.delete("CALENDAR_CONFIG_FILE")
    end
  end

  test "subscribe button is visible on calendar page when user has no calendar share" do
    skip "No google_calendar_id in community settings" unless @calendar_id.present?

    # Delete any existing calendar shares for this user
    CalendarShare.where(user_id: @user.id).destroy_all

    visit calendar_index_path

    # The subscribe button should be visible on the calendar page
    assert_selector "form[action='#{calendar_shares_path}']", visible: true
  end

  test "subscribe button is hidden on calendar page when user already has calendar share" do
    skip "No google_calendar_id in community settings" unless @calendar_id.present?

    # Ensure the user has a calendar share
    CalendarShare.find_or_create_by(user_id: @user.id, calendar_id: @calendar_id) do |share|
      share.shared_at = Time.current
    end

    visit calendar_index_path

    # The subscribe button should not be visible
    assert_no_selector "form[action='#{calendar_shares_path}']"
  end
end
