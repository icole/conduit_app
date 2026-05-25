# frozen_string_literal: true

require "test_helper"

class Api::V1::AuthRefreshTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:email_user)
    @community = communities(:crow_woods)
  end

  test "refresh returns new token for recently expired token" do
    # Token expired 3 days ago (within 7-day grace)
    expired_token = JwtService.encode(
      { user_id: @user.id, community_id: @user.community_id, type: "auth" },
      -3.days
    )

    post api_v1_auth_refresh_url,
      headers: { "Authorization" => "Bearer #{expired_token}" },
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert json["auth_token"].present?
    assert_equal @user.id, json["user"]["id"]

    # Verify new token is valid
    decoded = JwtService.decode(json["auth_token"])
    assert_not_nil decoded
    assert_equal @user.id, decoded[:user_id]
  end

  test "refresh rejects token expired more than 7 days ago" do
    # Token expired 10 days ago (outside grace window)
    old_token = JwtService.encode(
      { user_id: @user.id, community_id: @user.community_id, type: "auth" },
      -10.days
    )

    post api_v1_auth_refresh_url,
      headers: { "Authorization" => "Bearer #{old_token}" },
      as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "token_expired_beyond_refresh", json["error"]
  end

  test "refresh rejects token with invalid signature" do
    payload = { user_id: @user.id, community_id: @user.community_id, type: "auth", exp: 1.day.ago.to_i }
    bad_token = JWT.encode(payload, "wrong_secret", "HS256")

    post api_v1_auth_refresh_url,
      headers: { "Authorization" => "Bearer #{bad_token}" },
      as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "invalid_token", json["error"]
  end

  test "refresh rejects non-auth token type" do
    expired_token = JwtService.encode(
      { user_id: @user.id, community_id: @user.community_id, type: "password_reset" },
      -1.day
    )

    post api_v1_auth_refresh_url,
      headers: { "Authorization" => "Bearer #{expired_token}" },
      as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "invalid_token", json["error"]
  end

  test "refresh rejects if user no longer exists" do
    nonexistent_user_id = 999999
    expired_token = JwtService.encode(
      { user_id: nonexistent_user_id, community_id: @community.id, type: "auth" },
      -1.day
    )

    post api_v1_auth_refresh_url,
      headers: { "Authorization" => "Bearer #{expired_token}" },
      as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "invalid_token", json["error"]
  end

  test "refresh rejects valid (non-expired) token" do
    valid_token = JwtService.generate_auth_token(@user)

    post api_v1_auth_refresh_url,
      headers: { "Authorization" => "Bearer #{valid_token}" },
      as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "token_not_expired", json["error"]
  end

  test "refresh rejects request with no token" do
    post api_v1_auth_refresh_url, as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "invalid_token", json["error"]
  end
end
