require "test_helper"

# CON-72: meal notifications reach phones the way task reminders do (they
# used to go to browser push, which nothing ever subscribed to)
class MealNotificationPushTest < ActiveJob::TestCase
  setup do
    @member = users(:two)
    @member.push_devices.create!(token: "phone-2", platform: "apple")
    @meal = Meal.create!(title: "Harvest dinner", scheduled_at: 3.days.from_now, rsvp_deadline: 2.days.from_now)
  end

  def pushes
    enqueued_jobs.select { |job| job["job_class"] == "ApplicationPushNotificationJob" }.map { |job| job["arguments"][1] }
  end

  test "an RSVP reminder goes to the member's phone and opens the meal" do
    MealNotificationService.rsvp_deadline_reminder(@meal, @member)

    assert_equal 1, pushes.size
    assert_equal "RSVPs Closing Soon!", pushes.first["title"]
    assert_equal "/meals/#{@meal.id}", pushes.first.dig("data", "path")
  end

  test "and it's in the bell too" do
    MealNotificationService.rsvp_deadline_reminder(@meal, @member)

    assert @member.in_app_notifications.needs_you.exists?(notifiable: @meal)
  end
end
