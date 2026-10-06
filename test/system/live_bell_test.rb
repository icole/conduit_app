require "application_system_test_case"

# CON-72: in the apps, the bell's count changes while you look at a page
class LiveBellTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 1200 ], options: { name: :ios_app } do |options|
    options.add_argument("--user-agent=Mozilla/5.0 (iPhone) Conduit iOS (Turbo Native)")
  end

  test "a new notification updates the bell without reloading the page" do
    member = users(:two)
    meal = Meal.create!(title: "Dinner", scheduled_at: 3.days.from_now, rsvp_deadline: 2.days.from_now)
    sign_in_as(member)
    visit tasks_url
    assert_selector "turbo-cable-stream-source[connected]", visible: false
    assert_selector "#native-bell[data-bridge-count='0']", visible: false

    perform_enqueued_jobs do
      member.in_app_notifications.create!(title: "RSVP for dinner", notification_type: "rsvp_deadline", notifiable: meal)
    end

    assert_selector "#native-bell[data-bridge-count='1']", visible: false
  end
end
