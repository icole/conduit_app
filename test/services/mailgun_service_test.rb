require "test_helper"

class MailgunServiceTest < ActiveSupport::TestCase
  def setup
    @service = MailgunService.new
  end

  test "initializes with required environment variables" do
    assert_not_nil @service
  end

  test "raises error when environment variables are missing" do
    original_api_key = ENV["MAILGUN_API_KEY"]
    original_domain = ENV["MAILGUN_DOMAIN"]

    ENV["MAILGUN_API_KEY"] = nil
    ENV["MAILGUN_DOMAIN"] = nil

    assert_raises(MailgunService::MailgunError) do
      MailgunService.new
    end
  ensure
    ENV["MAILGUN_API_KEY"] = original_api_key
    ENV["MAILGUN_DOMAIN"] = original_domain
  end

  # Note: These tests would require Mailgun API credentials to run fully
  # For now, we're just testing that the service initializes correctly
  # In a real environment, you'd want to use VCR or similar to record HTTP interactions
end
