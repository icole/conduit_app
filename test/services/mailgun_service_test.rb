require "test_helper"

class MailgunServiceTest < ActiveSupport::TestCase
  def setup
    @service = MailgunService.new
  end

  test "initializes with required environment variables" do
    assert_not_nil @service
  end

  test "raises error when environment variables are missing" do
    ENV.stub :[], nil do
      assert_raises(MailgunService::MailgunError) do
        MailgunService.new
      end
    end
  end

  # Note: These tests would require Mailgun API credentials to run fully
  # For now, we're just testing that the service initializes correctly
  # In a real environment, you'd want to use VCR or similar to record HTTP interactions
end