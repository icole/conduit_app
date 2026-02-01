require "test_helper"
require "minitest/mock"

class ChatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin_user)
    @regular_user = users(:regular_user)
    @other_user = users(:one)
    @community = communities(:crow_woods)

    @admin_token = JwtService.generate_auth_token(@admin_user)
    @creator_token = JwtService.generate_auth_token(@regular_user)
    @other_token = JwtService.generate_auth_token(@other_user)

    @channel_id = "crow-woods-test-channel"
  end

  # --- destroy_channel tests ---

  test "admin can delete channel they did not create" do
    mock_channel = Minitest::Mock.new
    mock_channel.expect :query, { "channel" => { "created_by" => { "id" => @other_user.id.to_s } } }, [], user_id: @admin_user.id.to_s
    mock_channel.expect :delete, true

    mock_client = Minitest::Mock.new
    mock_client.expect :channel, mock_channel, [ "team" ], channel_id: @channel_id

    StreamChatClient.stub :configured?, true do
      StreamChatClient.stub :client, mock_client do
        delete destroy_chat_channel_url(@channel_id),
          headers: { "Authorization" => "Bearer #{@admin_token}" },
          as: :json

        assert_response :ok
        json = JSON.parse(response.body)
        assert json["success"]
        assert_equal @channel_id, json["channel_id"]
      end
    end

    mock_client.verify
    mock_channel.verify
  end

  test "channel creator can delete their own channel" do
    mock_channel = Minitest::Mock.new
    mock_channel.expect :query, { "channel" => { "created_by" => { "id" => @regular_user.id.to_s } } }, [], user_id: @regular_user.id.to_s
    mock_channel.expect :delete, true

    mock_client = Minitest::Mock.new
    mock_client.expect :channel, mock_channel, [ "team" ], channel_id: @channel_id

    StreamChatClient.stub :configured?, true do
      StreamChatClient.stub :client, mock_client do
        delete destroy_chat_channel_url(@channel_id),
          headers: { "Authorization" => "Bearer #{@creator_token}" },
          as: :json

        assert_response :ok
        json = JSON.parse(response.body)
        assert json["success"]
      end
    end

    mock_client.verify
    mock_channel.verify
  end

  test "non-admin non-creator cannot delete channel" do
    mock_channel = Minitest::Mock.new
    mock_channel.expect :query, { "channel" => { "created_by" => { "id" => @regular_user.id.to_s } } }, [], user_id: @other_user.id.to_s

    mock_client = Minitest::Mock.new
    mock_client.expect :channel, mock_channel, [ "team" ], channel_id: @channel_id

    StreamChatClient.stub :configured?, true do
      StreamChatClient.stub :client, mock_client do
        delete destroy_chat_channel_url(@channel_id),
          headers: { "Authorization" => "Bearer #{@other_token}" },
          as: :json

        assert_response :forbidden
        json = JSON.parse(response.body)
        assert_match(/admin.*creator|creator.*admin/i, json["error"])
      end
    end

    mock_client.verify
    mock_channel.verify
  end

  test "unauthenticated request to destroy_channel returns 401" do
    StreamChatClient.stub :configured?, true do
      delete destroy_chat_channel_url(@channel_id), as: :json

      assert_response :unauthorized
    end
  end
end
