require "application_system_test_case"

# CON-72: opening a notification goes straight to what it's about, in one
# visit (so the apps show one transition), and marks it read on the way
class NotificationsTest < ApplicationSystemTestCase
  test "opening an update goes straight to it and marks it read" do
    member = users(:two)
    meal = Meal.create!(title: "Dinner", scheduled_at: 3.days.from_now, rsvp_deadline: 2.days.from_now)
    update = member.in_app_notifications.create!(title: "Sam is cooking Friday", notification_type: "cook_assigned",
      notifiable: meal, action_url: meal_path(meal))

    sign_in_as(member)
    visit notifications_path
    within("#updates") { click_on "Sam is cooking Friday" }

    assert_current_path meal_path(meal)
    assert 50.times.any? { update.reload.read? || (sleep 0.1) && false }, "marked read"
  end
end
