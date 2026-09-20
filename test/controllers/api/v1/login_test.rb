# frozen_string_literal: true

require "test_helper"

class Api::V1::LoginTest < ActionDispatch::IntegrationTest
  setup do
    @crow_woods = communities(:crow_woods)
    @other = communities(:other_community)
    @user = users(:email_user) # crow-woods, password "testpassword123"

    # Same email, different community, different password: the lookup must be
    # scoped by community or one of these logins authenticates the wrong person.
    @twin = ActsAsTenant.with_tenant(@other) do
      User.create!(name: "Twin", email: @user.email, password: "otherpassword1", password_confirmation: "otherpassword1")
    end
  end

  test "login requires community_domain" do
    post api_v1_login_url, params: { email: @user.email, password: "testpassword123" }, as: :json

    assert_response :bad_request
    assert_equal "community_domain_required", JSON.parse(response.body)["error"]
  end

  test "login authenticates the user in the named community, not a same-email user elsewhere" do
    post api_v1_login_url,
      params: { email: @user.email, password: "otherpassword1", community_domain: @other.domain },
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @twin.id, json["user"]["id"]
    assert_equal @other.id, JwtService.decode(json["auth_token"])[:community_id]
  end

  test "login rejects the right password for the wrong community" do
    # crow-woods user's password, but asking the other community
    post api_v1_login_url,
      params: { email: @user.email, password: "testpassword123", community_domain: @other.domain },
      as: :json

    assert_response :unauthorized
    assert_nil JSON.parse(response.body)["auth_token"]
  end

  test "login rejects an unknown community_domain" do
    post api_v1_login_url,
      params: { email: @user.email, password: "testpassword123", community_domain: "nope.example" },
      as: :json

    assert_response :unauthorized
    assert_nil JSON.parse(response.body)["auth_token"]
  end

  test "login still works for the original community" do
    post api_v1_login_url,
      params: { email: @user.email, password: "testpassword123", community_domain: @crow_woods.domain },
      as: :json

    assert_response :ok
    assert_equal @user.id, JSON.parse(response.body)["user"]["id"]
  end
end
