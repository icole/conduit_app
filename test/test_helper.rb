ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    OmniAuth.config.test_mode = true

    def sign_in_user(user_attrs = {})
      auth_attrs = {
        provider: "google_oauth2",
        uid: user_attrs[:uid] || "123456788",
        info: {
          name: user_attrs[:name] || "Test User",
          email: user_attrs[:email] || "test@example.com"
        }
      }

      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        auth_attrs
      )

      get "/auth/google_oauth2/callback"
    end
  end
end
