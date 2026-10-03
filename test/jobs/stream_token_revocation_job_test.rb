require "test_helper"
require "minitest/mock"
require_relative "../support/fake_stream_client"

class StreamTokenRevocationJobTest < ActiveJob::TestCase
  test "suspending a community revokes its members' chat tokens" do
    community = communities(:crow_woods)
    member_ids = ActsAsTenant.with_tenant(community) { User.pluck(:id) }

    assert_enqueued_with(job: StreamTokenRevocationJob) { community.suspend! }

    fake = FakeStreamClient.new
    StreamChatClient.stub(:configured?, true) do
      StreamChatClient.stub(:client, fake) { perform_enqueued_jobs(only: StreamTokenRevocationJob) }
    end
    assert_equal member_ids.map(&:to_s).sort, fake.revoked.map { |r| r[:user_id] }.sort
  end
end
