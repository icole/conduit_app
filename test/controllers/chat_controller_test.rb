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

  # --- token_expired error tests ---

  test "expired token returns token_expired error" do
    expired_token = JwtService.encode(
      { user_id: @admin_user.id, community_id: @community.id, type: "auth" },
      -2.days
    )

    StreamChatClient.stub :configured?, true do
      post create_chat_channel_url,
        params: { name: "Test Channel" },
        headers: { "Authorization" => "Bearer #{expired_token}" },
        as: :json

      assert_response :unauthorized
      json = JSON.parse(response.body)
      assert_equal "token_expired", json["error"]
    end
  end

  # --- Stream user sync ---

  test "token syncs the user to Stream with the shared payload, never the admin role" do
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
        get token_chat_index_url,
          headers: { "Authorization" => "Bearer #{@admin_token}" },
          as: :json

        assert_response :ok
        assert_equal "stream-token", JSON.parse(response.body)["token"]
      end
    end

    mock_client.verify
    mock_channel.verify
  end

  test "create_channel creates the channel inside the community's Stream team" do
    community_users = @community.users.order(:id)
    channel_id = "#{@community.slug}-pets"

    mock_channel = Minitest::Mock.new
    mock_channel.expect :create, {}, [ @admin_user.id.to_s ]

    mock_client = Minitest::Mock.new
    mock_client.expect :upsert_users, {}, [ community_users.map(&:stream_user_data) ]
    mock_client.expect :channel, mock_channel, [ "team" ],
      channel_id: channel_id,
      data: StreamChannelService.channel_data(@community, name: "Pets", members: community_users.map { |u| u.id.to_s })

    StreamChatClient.stub :configured?, true do
      StreamChatClient.stub :client, mock_client do
        post create_chat_channel_url,
          params: { name: "Pets" },
          headers: { "Authorization" => "Bearer #{@admin_token}" },
          as: :json

        assert_response :ok
        assert_equal channel_id, JSON.parse(response.body)["channel_id"]
      end
    end

    mock_client.verify
    mock_channel.verify
  end

  # --- no debug endpoints in a public build ---

  test "chat/debug is not routable" do
    get "/chat/debug", as: :json
    assert_response :not_found
  end

  test "chat/test_native is not routable" do
    get "/chat/test_native"
    assert_response :not_found
  end

  test "token is refused while the community is pending" do
    token = JwtService.generate_auth_token(users(:pending_admin))

    StreamChatClient.stub :configured?, true do
      get token_chat_index_url, headers: { "Authorization" => "Bearer #{token}" }, as: :json
    end

    assert_response :forbidden
    assert_equal "community_not_active", JSON.parse(response.body)["error"]
  end
end
