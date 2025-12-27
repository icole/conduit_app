ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/soft_delete_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include SoftDeleteTestHelper

    OmniAuth.config.test_mode = true

    # Set tenant for all tests
    setup do
      ActsAsTenant.current_tenant = communities(:crow_woods)
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

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

class ActionDispatch::IntegrationTest
  include ActiveRecord::TestFixtures

  setup do
    host! "crowwoods.test"
    # Use fixture accessor which is available in integration tests
    ActsAsTenant.current_tenant = communities(:crow_woods) if respond_to?(:communities)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end
end
