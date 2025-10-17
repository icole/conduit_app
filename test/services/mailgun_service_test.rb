require "test_helper"

class MailgunServiceTest < ActiveSupport::TestCase
  # Provide minimal stubs so tests don't depend on the Mailgun gem being installed in CI
  module ::Mailgun; end unless defined?(::Mailgun)
  class ::Mailgun::Client; def initialize(*) = nil; end unless defined?(::Mailgun::Client)
  class ::Mailgun::CommunicationError < StandardError; end unless defined?(::Mailgun::CommunicationError)

  test "initializes with required environment variables" do
    original_api_key = ENV["MAILGUN_API_KEY"]
    original_domain  = ENV["MAILGUN_DOMAIN"]

    ENV["MAILGUN_API_KEY"] = "test-api-key"
    ENV["MAILGUN_DOMAIN"]  = "example.com"

    # Ensure new doesn't blow up and returns a service instance
    service = MailgunService.new
    assert service
  ensure
    ENV["MAILGUN_API_KEY"] = original_api_key
    ENV["MAILGUN_DOMAIN"]  = original_domain
  end

  test "raises error when environment variables are missing" do
    original_api_key = ENV["MAILGUN_API_KEY"]
    original_domain  = ENV["MAILGUN_DOMAIN"]

    ENV["MAILGUN_API_KEY"] = nil
    ENV["MAILGUN_DOMAIN"]  = nil

    assert_raises(MailgunService::MailgunError) { MailgunService.new }
  ensure
    ENV["MAILGUN_API_KEY"] = original_api_key
    ENV["MAILGUN_DOMAIN"]  = original_domain
  end

  # Note: These tests would require Mailgun API credentials to run fully
  # For now, we're just testing that the service initializes correctly
  # In a real environment, you'd want to use VCR or similar to record HTTP interactions
end
