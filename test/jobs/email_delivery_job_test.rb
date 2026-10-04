# frozen_string_literal: true

require "test_helper"

class EmailDeliveryJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @community = communities(:crow_woods)
    ActsAsTenant.current_tenant = @community
  end

  # Mail goes through Resend, so there's no SMTP advice to give
  test "a failed delivery is logged as the error's class and message" do
    job = EmailDeliveryJob.new

    assert_equal "Resend::Error: 422 invalid from address",
      job.send(:build_error_message, Resend::Error.new("422 invalid from address"))
    assert_equal "Net::OpenTimeout: connection timed out",
      job.send(:build_error_message, Net::OpenTimeout.new("connection timed out"))
  end
end
