require "test_helper"

# Meals are posted weeks ahead so people can sign up to cook first. One still
# without a head cook two weeks out, and again a week out, goes to everyone:
# in the bell, where it clears once someone leads it, and to their phones.
class MealNeedsCookJobTest < ActiveJob::TestCase
  setup do
    @community = communities(:crow_woods)
    @community.update!(time_zone: "America/Los_Angeles")
    @one = users(:one)
    @one.push_devices.create!(token: "phone-1", platform: "apple")
    @meal = Meal.create!(title: "Harvest dinner", scheduled_at: zone.local(2026, 11, 20, 18), rsvp_deadline: zone.local(2026, 11, 19, 18))
  end

  def zone = ActiveSupport::TimeZone["America/Los_Angeles"]

  def on(month, day, &block)
    travel_to(zone.local(2026, month, day, 9, 0), &block)
  end

  def run_on(month, day) = on(month, day) { MealNeedsCookJob.perform_now }

  def pushes
    enqueued_jobs.select { |job| job["job_class"] == "ApplicationPushNotificationJob" }.map { |job| job["arguments"][1] }
  end

  def entries(user = @one) = user.in_app_notifications.where(notifiable: @meal)

  test "nothing while there's more than two weeks to claim it" do
    run_on(11, 5)

    assert_empty entries
    assert_empty pushes
  end

  test "two weeks out with no head cook, everyone hears, in the bell and on their phone" do
    run_on(11, 6)

    assert_equal 1, entries(@one).count
    assert_equal 1, entries(users(:two)).count
    assert_equal [ "meal_needs_cook" ], entries.map(&:notification_type)
    assert_includes entries.first.title, "Harvest dinner"
    assert_equal [ "/meals/#{@meal.id}" ], pushes.map { |push| push.dig("data", "path") }
    assert entries.first.kind.needs_you?
  end

  test "once each: running again the same week sends nothing new" do
    run_on(11, 6)
    run_on(11, 7)

    assert_equal 1, pushes.size
  end

  test "a week out, again: the same bell entry, unread again" do
    run_on(11, 6)
    entries.first.mark_as_read!
    run_on(11, 13)

    assert_equal 1, entries.count
    assert entries.first.unread?
    assert_equal 2, pushes.size
  end

  test "a meal first posted inside the week gets one notice, not two" do
    run_on(11, 15)
    run_on(11, 16)

    assert_equal 1, pushes.size
  end

  test "a helper alone doesn't count: it still needs someone to lead" do
    @meal.meal_cooks.create!(user: users(:two), role: "helper")
    run_on(11, 6)

    assert_equal 1, entries(@one).count
  end

  test "with a head cook, nothing goes out, and an earlier notice leaves everyone's bell" do
    run_on(11, 6)
    @meal.meal_cooks.create!(user: users(:two), role: "head_cook")

    InAppNotification.settle_for(@one)
    assert_empty @one.in_app_notifications.needs_you.where(notifiable: @meal)

    run_on(11, 13)
    assert_equal 1, pushes.size
  end

  test "cancelled meals are left alone" do
    @meal.update!(status: "cancelled")
    run_on(11, 6)

    assert_empty entries
  end
end
