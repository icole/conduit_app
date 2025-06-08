require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  OmniAuth.config.test_mode = true

  def sign_in_user(user_attrs = {})
    default_attrs = {
      provider: "google_oauth2",
      uid: "123456789",
      info: {
        name: "Test User",
        email: "test@example.com"
      }
    }

    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      default_attrs.merge(user_attrs)
    )

    visit "/auth/google_oauth2/callback"
  end
end
