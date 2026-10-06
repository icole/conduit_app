require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  setup { sign_in_as(users(:admin_user)) }

  teardown { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test "on a phone the main sections sit in a tab bar at the bottom, the current one marked" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit meals_path

    within "nav[aria-label='Sections']" do
      assert_link "Home"
      assert_link "Tasks"
      assert_link "Calendar"
      assert_selector "a[aria-current='page']", text: "Meals"
    end

    tab_bar_bottom = page.evaluate_script("document.querySelector(\"nav[aria-label='Sections']\").getBoundingClientRect().bottom")
    assert_in_delta page.evaluate_script("window.innerHeight"), tab_bar_bottom, 1
  end

  test "on a phone More opens the rest of the sections" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit root_path

    assert_no_link "Docs"
    click_button "More"
    assert_link "Docs"
    assert_link "Households"
  end

  test "on a desktop the sections are in the top bar and the tab bar is gone" do
    visit tasks_path

    assert_no_selector "nav[aria-label='Sections']"
    within "nav[aria-label='Main']" do
      assert_selector "a[aria-current='page']", text: "Tasks"
      assert_link "Docs"
    end
  end
end
