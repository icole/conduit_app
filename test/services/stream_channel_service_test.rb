# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class StreamChannelServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:email_user)
    @community = communities(:crow_woods)
  end

  test "ensure_user_in_default_channels passes created_by_id for channel creation" do
    # Track what data is passed to channel initialization
    channel_init_calls = []

    mock_channel = Minitest::Mock.new
    # query succeeds (channel exists), then add_members succeeds
    StreamChannelService::DEFAULT_CHANNELS.each do
      mock_channel.expect :query, { "channel" => {} }, [], user_id: @user.id.to_s
      mock_channel.expect :add_members, true, [[ @user.id.to_s ]]
    end

    mock_client = Minitest::Mock.new
    StreamChannelService::DEFAULT_CHANNELS.each do |channel_data|
      channel_id = "#{@community.slug}-#{channel_data[:id]}"
      mock_client.expect :channel, mock_channel, ["team"], channel_id: channel_id, data: {
        name: channel_data[:name],
        created_by_id: @user.id.to_s
      }
    end

    StreamChatClient.stub :client, mock_client do
      StreamChannelService.ensure_user_in_default_channels(@user)
    end

    mock_client.verify
    mock_channel.verify
  end
end
