require "test_helper"
require "turbo/broadcastable/test_helper"

# CON-72: the apps' bell updates as things change, over Action Cable, not
# only when a page loads or a screen shows again
class BellBroadcastJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    @member = users(:two)
    @meal = Meal.create!(title: "Dinner", scheduled_at: 3.days.from_now, rsvp_deadline: 2.days.from_now)
    @task = Task.create!(title: "Sweep the porch", user: users(:one), workstream: workstreams(:general), due_date: Date.current)
  end

  # The count in the last bell sent to the member's pages, after whatever was queued runs
  def count_sent
    sent = capture_turbo_stream_broadcasts([ @member, :bell ]) { perform_enqueued_jobs }
    sent.last&.at_css("a[data-controller='bridge--bell']")&.[]("data-bridge-count")
  end

  def notify(kind, about)
    @member.in_app_notifications.create!(title: "Heads up", notification_type: kind, notifiable: about)
  end

  test "a new notification reaches the member's bell" do
    notify("rsvp_deadline", @meal)

    assert_equal "1", count_sent
  end

  test "RSVPing takes the reminder off the bell straight away" do
    notify("rsvp_deadline", @meal)
    count_sent

    @meal.meal_rsvps.create!(user: @member, status: "attending")
    assert_equal "0", count_sent
  end

  test "when someone takes work that needed someone, it comes off the bell" do
    notify("task_needs_someone", @task)
    count_sent

    @task.assignees << users(:three)
    assert_equal "0", count_sent
  end

  test "completing your task takes it off your bell" do
    @task.assignees << @member
    notify("task_assigned", @task)
    count_sent

    @task.update!(status: "completed")
    assert_equal "0", count_sent
  end

  test "when someone else signs up to lead a meal that needed a cook, it comes off your bell" do
    notify("meal_needs_cook", @meal)
    count_sent

    @meal.meal_cooks.create!(user: users(:three), role: "head_cook")
    assert_equal "0", count_sent
  end

  test "RSVPs closing takes the reminder off" do
    notify("meal_reminder", @meal)
    count_sent

    @meal.update!(rsvps_closed: true)
    assert_equal "0", count_sent
  end
end
