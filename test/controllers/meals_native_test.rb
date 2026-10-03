require "test_helper"

# The Meals tabs, as the apps and the website get them
class MealsNativeTest < ActionDispatch::IntegrationTest
  NATIVE = { "User-Agent" => "Conduit iOS/2 (Turbo Native)" }.freeze

  setup do
    user = users(:admin_user)
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  test "tabs switch inside the frame without proposing a native visit" do
    get meals_url, headers: NATIVE
    assert_select "nav[aria-label='Meal views'] a[data-turbo-frame='meals_content']", count: 4
    assert_select "nav[aria-label='Meal views'] a[data-turbo-action]", count: 0
  end

  test "a meal in the list opens as its own screen, not inside the frame" do
    get meals_url, headers: NATIVE
    assert_select "turbo-frame#meals_content[target='_top']"
  end

  test "the apps come back to the last tab, so pull-to-refresh stays put" do
    get meals_url(view: "past"), headers: NATIVE
    get meals_url, headers: NATIVE
    assert_select "nav[aria-label='Meal views'] a[aria-current='page']", text: "Past"
  end

  test "the web keeps the tab in the address instead" do
    get meals_url(view: "past")
    assert_select "nav[aria-label='Meal views'] a[data-turbo-frame='meals_content'][data-turbo-action='advance']", count: 4

    get meals_url
    assert_select "nav[aria-label='Meal views'] a[aria-current='page']", text: "Upcoming"
  end
end
