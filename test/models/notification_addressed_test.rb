require "test_helper"

# CON-72: a notification is "addressed" when the thing it asked of you is
# done, worked out from the current state, so nobody has to dismiss it
class NotificationAddressedTest < ActiveSupport::TestCase
  setup do
    @member = users(:two)
    @meal = Meal.create!(title: "Dinner", scheduled_at: 3.days.from_now, rsvp_deadline: 2.days.from_now)
    @task = Task.create!(title: "Sweep the porch", user: users(:one), workstream: workstreams(:general), due_date: Date.current)
  end

  def notify(kind, about)
    @member.in_app_notifications.create!(title: "Heads up", notification_type: kind, notifiable: about)
  end

  def settled(notification)
    InAppNotification.settle_for(@member)
    notification.reload
  end

  test "an RSVP reminder is addressed once you RSVP" do
    reminder = notify("rsvp_deadline", @meal)
    assert_nil settled(reminder).resolved_at

    @meal.meal_rsvps.create!(user: @member, status: "attending")
    assert settled(reminder).resolved_at
  end

  test "an RSVP reminder is addressed once the deadline has passed, RSVP or not" do
    reminder = notify("rsvp_deadline", @meal)
    travel_to(@meal.rsvp_deadline + 1.minute) { assert settled(reminder).resolved_at }
  end

  test "a task you were put on is addressed when it's done, or no longer yours" do
    @task.assignees << @member
    assigned = notify("task_assigned", @task)
    assert_nil settled(assigned).resolved_at

    @task.task_assignments.where(user: @member).destroy_all
    assert settled(assigned).resolved_at

    due = notify("task_due", @task)
    @task.assignees << @member
    assert_nil settled(due).resolved_at
    @task.update!(status: "completed")
    assert settled(due).resolved_at
  end

  test "work that needs someone is addressed once anyone takes it" do
    needs = notify("task_needs_someone", @task)
    assert_nil settled(needs).resolved_at

    @task.assignees << users(:three)
    assert settled(needs).resolved_at
  end

  test "updates are addressed by reading them" do
    update = notify("cook_assigned", @meal)
    assert_nil settled(update).resolved_at
    update.mark_as_read!
    assert update.reload.resolved_at
  end

  test "the day-before meal reminder needs you until you RSVP, like the RSVP reminder" do
    reminder = notify("meal_reminder", @meal)
    assert_nil settled(reminder).resolved_at
    assert_includes @member.in_app_notifications.needs_you, reminder

    @meal.meal_rsvps.create!(user: @member, status: "attending")
    assert settled(reminder).resolved_at
  end

  test "something deleted since is addressed" do
    reminder = notify("rsvp_deadline", @meal)
    @meal.discard!
    assert settled(reminder).resolved_at
  end

  test "the bell counts what still needs you, not every unread update" do
    notify("rsvp_deadline", @meal)
    @task.assignees << @member
    notify("task_assigned", @task)
    notify("cook_assigned", @meal)

    InAppNotification.settle_for(@member)
    assert_equal 2, @member.in_app_notifications.needs_you.count
    assert_equal 1, @member.in_app_notifications.updates.unread.count
  end
end
