# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# CON-81: deleting a Conduit account must retire the Stream user, otherwise
# the chat identity (with its channel memberships) survives account deletion.
class StreamUserRemovalJobTest < ActiveJob::TestCase
  class FakeStreamClient
    attr_reader :deactivated, :revoked

    def initialize(deactivate_error: nil)
      @deactivated = []
      @revoked = []
      @deactivate_error = deactivate_error
    end

    def deactivate_user(id, **_options)
      raise @deactivate_error if @deactivate_error

      @deactivated << id
      {}
    end

    def revoke_user_token(id, _before)
      @revoked << id
      {}
    end
  end

  test "deactivates the Stream user and revokes their tokens" do
    client = FakeStreamClient.new

    StreamChatClient.stub(:configured?, true) do
      StreamChatClient.stub(:client, client) do
        StreamUserRemovalJob.perform_now("42")
      end
    end

    assert_equal [ "42" ], client.deactivated
    assert_equal [ "42" ], client.revoked
  end

  test "does nothing when Stream is not configured" do
    client = FakeStreamClient.new

    StreamChatClient.stub(:configured?, false) do
      StreamChatClient.stub(:client, client) do
        StreamUserRemovalJob.perform_now("42")
      end
    end

    assert_empty client.deactivated
    assert_empty client.revoked
  end

  test "still revokes tokens when deactivation fails, and never raises" do
    client = FakeStreamClient.new(deactivate_error: StandardError.new("Stream is down"))

    StreamChatClient.stub(:configured?, true) do
      StreamChatClient.stub(:client, client) do
        StreamUserRemovalJob.perform_now("42")
      end
    end

    assert_equal [ "42" ], client.revoked
  end
end
