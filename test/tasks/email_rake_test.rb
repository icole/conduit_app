require "test_helper"
require "rake"
require "minitest/mock"

# email:test called Community#smtp_from_email, which doesn't exist, so it
# crashed whenever there was a community (CON-34)
class EmailRakeTest < ActiveSupport::TestCase
  setup { Rails.application.load_tasks if Rake::Task.tasks.empty? }
  teardown { ENV.delete("RESEND_API_KEY") }

  test "email:test sends from the app's address" do
    ENV["RESEND_API_KEY"] = "re_test"
    sent = nil
    Resend::Emails.stub(:send, ->(params) { sent = params; { "id" => "test-id" } }) do
      Rake::Task["email:test"].reenable
      capture_io { Rake::Task["email:test"].invoke("someone@example.com") }
    end

    assert_equal "Conduit <noreply@conduitcoho.app>", sent[:from]
    assert_equal [ "someone@example.com" ], Array(sent[:to])
  end

  test "email:test_connection lists the verified domains" do
    ENV["RESEND_API_KEY"] = "re_test"
    out = Resend::Domains.stub(:list, Resend::Response.new({ "data" => [ { "name" => "conduitcoho.app", "status" => "verified" } ] }, {})) do
      Rake::Task["email:test_connection"].reenable
      capture_io { Rake::Task["email:test_connection"].invoke }.first
    end

    assert_match "✓ conduitcoho.app (verified)", out
  end
end
