require "application_system_test_case"

class PastMealsTest < ApplicationSystemTestCase
  setup do
    25.times do |i|
      at = (i + 10).days.ago.change(hour: 18)
      Meal.create!(title: "Older meal #{i + 1}", scheduled_at: at, rsvp_deadline: at - 1.day, status: "completed")
    end
  end

  test "Show older meals loads the next page under the first" do
    sign_in_as(users(:one))
    visit meals_url(view: "past")
    assert_selector "[id^='meal_']", count: 20

    click_link "Show older meals"
    assert_selector "[id^='meal_']", count: 26
    assert_no_link "Show older meals"
    assert_current_path meals_path(view: "past")
  end
end

class PastMealsInAppTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 1200 ], options: { name: :ios_app_v2 } do |options|
    options.add_argument("--user-agent=Mozilla/5.0 (iPhone) Conduit iOS/2 (Turbo Native)")
  end

  setup do
    25.times do |i|
      at = (i + 10).days.ago.change(hour: 18)
      Meal.create!(title: "Older meal #{i + 1}", scheduled_at: at, rsvp_deadline: at - 1.day, status: "completed")
    end
  end

  test "Show older meals works in the app's list too" do
    sign_in_as(users(:one))
    visit meals_url(view: "past")
    click_link "Show older meals"
    assert_selector "[id^='meal_']", count: 26
    assert_no_link "Show older meals"
  end
end
