require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  OmniAuth.config.test_mode = true

  setup { before_each_system_test }

  # Start every test signed out. Capybara's reset between tests clears cookies
  # and only then navigates away, so a background request finishing in between
  # (the dashboard lazy-loads frames) can set a fresh session cookie. The next
  # test's Google sign-in would then link accounts instead of switching users
  # and run as the wrong person. Nothing is loaded yet here, so this is final.
  def before_each_system_test
    browser = page.driver.browser
    browser.execute_cdp("Network.clearBrowserCookies") if browser.respond_to?(:execute_cdp)
  end

  def sign_in_user(user_attrs = {})
    default_attrs = {
      provider: "google_oauth2",
      uid: "test_oauth_uid_999",  # Non-conflicting with fixtures
      info: {
        name: "Test User",
        email: "test_oauth_user@example.com"
      }
    }

    auth = default_attrs.deep_merge(user_attrs)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(auth)

    # A brand-new account needs an invitation, exactly as in production.
    unless User.exists?(provider: "google_oauth2", uid: auth[:uid].to_s)
      visit accept_invitation_path(Invitation.create!.token)
    end

    visit "/auth/google_oauth2/callback"
  end

  # Sign in as a specific fixture user
  def sign_in_as(user)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: user.provider || "google_oauth2",
      uid: user.uid,
      info: {
        name: user.name,
        email: user.email
      }
    )

    visit "/auth/google_oauth2/callback"
  end
end
