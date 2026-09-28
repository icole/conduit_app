require "test_helper"

class CalendarEventModalTest < ActionView::TestCase
  def event(**overrides)
    start_time = Time.zone.local(2026, 10, 3, 18)
    OpenStruct.new(google_event_id: "abc123", title: "Potluck", start_time: start_time, end_time: start_time + 2.hours,
                   location: "Common House", description: "Bring a dish to share.", all_day: false,
                   time_range: "Oct 03, 2026 • 6:00 PM - 8:00 PM", **overrides)
  end

  test "the event popup has everything the old event page did, with Edit and Delete" do
    render partial: "calendar/event_modal", locals: { event: event, modal_id: "event_abc123_modal" }

    assert_select "dialog#event_abc123_modal" do
      assert_select "h4", "Potluck"
      assert_select "*", text: /Common House/
      assert_select "*", text: /Bring a dish to share\./
      assert_select "a[href='#{edit_calendar_event_path(google_event_id: 'abc123')}']", text: /Edit/
      assert_select "a[href='#{calendar_event_path(google_event_id: 'abc123')}'][data-turbo-method='delete']", text: /Delete/
      assert_select "a", text: "View Details", count: 0
    end
  end

  test "no description line when the event has none" do
    render partial: "calendar/event_modal", locals: { event: event(description: nil), modal_id: "event_abc123_modal" }
    assert_select "[data-event-description]", count: 0
  end
end
