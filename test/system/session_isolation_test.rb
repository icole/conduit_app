require "application_system_test_case"

# Capybara's reset clears cookies and only then navigates away, so a
# background request finishing in between (the dashboard lazy-loads frames)
# can set a fresh session cookie that the next test starts with. Signing in
# through the Google callback while signed in links accounts instead of
# switching users, so that test then runs as the wrong person.
class SessionIsolationTest < ApplicationSystemTestCase
  test "a session cookie left over from the last test doesn't carry into the next" do
    sign_in_as(users(:one))
    visit account_path
    leftover = page.driver.browser.manage.all_cookies.find { |c| c[:name].include?("session") }
    assert leftover, "expected a session cookie to plant"

    # What teardown does, then the late Set-Cookie that slips past it
    Capybara.reset_sessions!
    visit "/up"
    page.driver.browser.manage.add_cookie(leftover.slice(:name, :value, :path))
    page.driver.browser.navigate.to("about:blank")

    # What the next test does first
    before_each_system_test

    sign_in_as(users(:oauth_no_password))
    visit account_path
    within("#password-change-section") { assert_text "Set a password to enable email login" }
  end
end
