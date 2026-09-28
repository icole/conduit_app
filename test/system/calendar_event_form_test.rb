require "application_system_test_case"

# The new-event form as the iOS app shows it on a phone.
class CalendarEventFormTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 900 ], options: { name: :ios_app_v2 } do |options|
    options.add_argument("--user-agent=Mozilla/5.0 (iPhone) Conduit iOS/2 (Turbo Native)")
  end

  def set_time(label, value)
    field = find_field(label)
    page.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('change', { bubbles: true }))", field, value)
  end

  test "one date and two times; moving the start keeps the length, and past midnight makes it two days" do
    sign_in_as(users(:one))
    visit new_calendar_event_url(calendar_event: { start_time: "2026-10-03 18:00" })

    assert_field "Date *", with: "2026-10-03"
    assert_field "Starts *", with: "18:00"
    assert_field "Ends *", with: "19:00"
    assert_no_field "Ends on *"
    page.save_screenshot(ENV["EVENT_FORM_SCREENSHOT"]) if ENV["EVENT_FORM_SCREENSHOT"]

    set_time "Ends *", "20:30"      # a 2½ hour event
    set_time "Starts *", "19:00"
    assert_field "Ends *", with: "21:30"

    set_time "Starts *", "22:30"    # now runs past midnight
    assert_field "Ends *", with: "01:00"
    assert_checked_field "Ends on a different day"
    assert_field "Ends on *", with: "2026-10-04"

    uncheck "Ends on a different day"
    assert_no_field "Ends on *"
  end
end
