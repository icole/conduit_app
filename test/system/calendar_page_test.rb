# frozen_string_literal: true

require "application_system_test_case"

class CalendarPageTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @community = communities(:crow_woods)
    @calendar_id = @community.settings&.dig("google_calendar_id")

    sign_in_as(@user)

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

  test "subscribe dropdown is visible on calendar page" do
    skip "No google_calendar_id in community settings" unless @calendar_id.present?

    visit calendar_index_path

    assert_selector ".dropdown", text: "Subscribe"
  end

  test "subscribe dropdown contains iCal options on calendar page" do
    skip "No google_calendar_id in community settings" unless @calendar_id.present?

    visit calendar_index_path

    find(".dropdown", text: "Subscribe").click

    assert_selector "a", text: "Subscribe in Calendar App"
    assert_selector "button", text: "Copy iCal URL"
  end
end
