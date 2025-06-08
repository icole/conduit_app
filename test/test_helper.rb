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

      get "/auth/google_oauth2/callback"
    end
  end
end
