# frozen_string_literal: true

require "test_helper"

class Api::V1::LogoutTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:email_user)
    @token = JwtService.generate_auth_token(@user)
  end

  test "logout revokes the mobile token, not just the session" do
    get api_v1_auth_check_url, headers: { "Authorization" => "Bearer #{@token}" }, as: :json
    assert_response :ok

    delete api_v1_logout_url, headers: { "Authorization" => "Bearer #{@token}" }, as: :json
    assert_response :ok

    get api_v1_auth_check_url, headers: { "Authorization" => "Bearer #{@token}" }, as: :json
    assert_response :unauthorized
  end
end
