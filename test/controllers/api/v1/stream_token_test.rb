# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Api::V1::StreamTokenTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin_user)
    @community = communities(:crow_woods)
    @admin_token = JwtService.generate_auth_token(@admin_user)
  end

  test "stream_token syncs the user to Stream with the shared payload, never the admin role" do
    mock_channel = Minitest::Mock.new
    StreamChannelService::DEFAULT_CHANNELS.each do
      mock_channel.expect :query, { "channel" => {} }, [], user_id: @admin_user.id.to_s
      mock_channel.expect :add_members, true, [ [ @admin_user.id.to_s ] ]
    end

    mock_client = Minitest::Mock.new
    mock_client.expect :upsert_user, {}, [ @admin_user.stream_user_data ]
    StreamChannelService::DEFAULT_CHANNELS.each do |channel_data|
      mock_client.expect :channel, mock_channel, [ "team" ],
        channel_id: "#{@community.slug}-#{channel_data[:id]}",
        data: StreamChannelService.channel_data(@community, name: channel_data[:name], created_by_id: @admin_user.id.to_s)
    end
    mock_client.expect :create_token, "stream-token", [ @admin_user.id.to_s ]

    StreamChatClient.stub :configured?, true do
      StreamChatClient.stub :client, mock_client do
        get api_v1_stream_token_url,
          headers: { "Authorization" => "Bearer #{@admin_token}" },
          as: :json

        assert_response :ok
        assert_equal "stream-token", JSON.parse(response.body)["token"]
      end
    end

    mock_client.verify
    mock_channel.verify
  end
end
