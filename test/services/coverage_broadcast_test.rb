require "test_helper"
require "minitest/mock"

class CoverageBroadcastTest < ActiveSupport::TestCase
  setup do
    @community = communities(:crow_woods)
    @task = recurring_tasks(:garbage_night).instance_for(Date.new(2026, 3, 5))
    @task.release!(users(:one))
  end

  test "posts the release to the community's chores channel, linking to the queue" do
    sent = nil
    channel = Object.new
    channel.define_singleton_method(:query) { |**| {} }
    channel.define_singleton_method(:send_message) { |message, user_id| sent = [ message, user_id ] }

    client = Minitest::Mock.new
    client.expect :upsert_user, true, [ Hash ]
    client.expect :channel, channel, [ "team" ], channel_id: "crow-woods-chores",
      data: StreamChannelService.channel_data(@community, name: "Chores & Coverage", created_by_id: users(:one).id.to_s)

    StreamChatClient.stub :configured?, true do
      StreamChatClient.stub :client, client do
        CoverageBroadcast.new(@task).deliver
      end
    end

    client.verify
    message, user_id = sent
    assert_equal users(:one).id.to_s, user_id
    assert_includes message[:text], "Take out garbage & recycling"
    assert_includes message[:text], "Jane"
    assert_includes message[:text], "http://crowwoods.test/tasks?tab=available"
  end

  test "uses the channel configured in community settings" do
    @community.update!(settings: @community.settings.merge("coverage_chat_channel" => "general"))
    assert_equal "crow-woods-general", CoverageBroadcast.channel_id(@community)
  end

  test "does nothing when chat is off for the community" do
    @community.update!(chat_enabled: false)
    StreamChatClient.stub :configured?, true do
      StreamChatClient.stub :client, -> { flunk "should not talk to Stream" } do
        assert_nil CoverageBroadcast.new(@task.reload).deliver
      end
    end
  end
end
