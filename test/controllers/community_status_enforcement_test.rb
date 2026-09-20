# frozen_string_literal: true

require "test_helper"

# What members of a pending or suspended community can and cannot do.
class CommunityStatusEnforcementTest < ActionDispatch::IntegrationTest
  def sign_in(user, host:)
    host! host
    post login_path, params: { email: user.email, password: "testpassword123" }
    assert_equal user.id, session[:user_id]
  end

  # --- pending: full app minus metered features, with a banner ---

  test "pending community members can use the app and see the approval banner" do
    sign_in users(:pending_admin), host: "pending.test"

    get dashboard_index_url
    assert_response :success
    assert_match(/approved/i, response.body)
  end

  test "pending community members are redirected away from chat with an explanation" do
    sign_in users(:pending_admin), host: "pending.test"

    get chat_index_url
    assert_redirected_to root_path
    assert_match(/approved/i, flash[:alert])
  end

  test "active community members see no approval banner" do
    sign_in users(:email_user), host: "crowwoods.test"

    get dashboard_index_url
    assert_response :success
    assert_no_match(/until your community is approved/i, response.body)
  end

  # --- suspended: nothing but account/session pages ---

  test "suspended community members get a suspended page instead of the app" do
    sign_in users(:suspended_user), host: "suspended.test"

    get dashboard_index_url
    assert_response :forbidden
    assert_match(/suspended/i, response.body)
  end

  test "suspended community members can still reach account deletion and log out" do
    sign_in users(:suspended_user), host: "suspended.test"

    get delete_account_path
    assert_response :success

    delete logout_path
    assert_redirected_to root_path
  end

  test "suspended community members get JSON 403 from the API" do
    user = users(:suspended_user)
    token = JwtService.generate_auth_token(user)

    get api_v1_auth_check_url, headers: { "Authorization" => "Bearer #{token}" }, as: :json
    assert_response :forbidden
    assert_equal "community_suspended", JSON.parse(response.body)["error"]
  end
end
