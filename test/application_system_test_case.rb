require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  OmniAuth.config.test_mode = true

  def sign_in_user(user_attrs = {})
    default_attrs = {
      provider: "google_oauth2",
      uid: "test_oauth_uid_999",  # Non-conflicting with fixtures
      info: {
        name: "Test User",
        email: "test_oauth_user@example.com"
      }
    }

    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      default_attrs.deep_merge(user_attrs)
    )

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
