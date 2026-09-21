# frozen_string_literal: true

require "test_helper"

# other_community is active but has chat/docs flags off.
class FeatureFlagEnforcementTest < ActionDispatch::IntegrationTest
  setup do
    @member = users(:other_member)
    @token = JwtService.generate_auth_token(@member)
  end

  test "api stream_token reports chat_disabled for an active community with chat off" do
    StreamChatClient.stub :configured?, true do
      get api_v1_stream_token_url, headers: { "Authorization" => "Bearer #{@token}" }, as: :json
    end

    assert_response :forbidden
    assert_equal "chat_disabled", JSON.parse(response.body)["error"]
  end

  test "chat token reports chat_disabled for an active community with chat off" do
    StreamChatClient.stub :configured?, true do
      get token_chat_index_url, headers: { "Authorization" => "Bearer #{@token}" }, as: :json
    end

    assert_response :forbidden
    assert_equal "chat_disabled", JSON.parse(response.body)["error"]
  end

  test "liveblocks auth reports docs_disabled for an active community with docs off" do
    host! "other.test"
    post login_path, params: { email: @member.email, password: "testpassword123" }

    post api_liveblocks_auth_url, params: { room: "document:1" }, as: :json

    assert_response :forbidden
    assert_equal "docs_disabled", JSON.parse(response.body)["error"]
  end

  test "navbar hides Chat when the community has chat off" do
    host! "other.test"
    post login_path, params: { email: @member.email, password: "testpassword123" }

    get dashboard_index_url
    assert_response :success
    assert_select "a[href=?]", chat_index_path, count: 0
  end

  test "navbar shows Chat when the community has chat on" do
    host! "crowwoods.test"
    post login_path, params: { email: users(:email_user).email, password: "testpassword123" }

    get dashboard_index_url
    assert_select "a[href=?]", chat_index_path, minimum: 1
  end
end
