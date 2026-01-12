# frozen_string_literal: true

require "test_helper"

class EmailDeliveryJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @community = communities(:crow_woods)
    ActsAsTenant.current_tenant = @community
  end

  test "build_error_message adds context for SMTP authentication errors" do
    job = EmailDeliveryJob.new
    error = Net::SMTPAuthenticationError.new("535 5.7.8 Error: authentication failed")

    message = job.send(:build_error_message, error)

    assert_includes message, "SMTPAuthenticationError"
    assert_includes message, "authentication failed"
    assert_includes message, "Verify SMTP credentials"
  end

  test "build_error_message adds context for timeout errors" do
    job = EmailDeliveryJob.new

    timeout_error = Net::OpenTimeout.new("connection timed out")
    message = job.send(:build_error_message, timeout_error)

    assert_includes message, "timed out"
  end

  test "build_error_message returns base message for unknown errors" do
    job = EmailDeliveryJob.new
    error = StandardError.new("something went wrong")

    message = job.send(:build_error_message, error)

    assert_equal "StandardError: something went wrong", message
  end
end
