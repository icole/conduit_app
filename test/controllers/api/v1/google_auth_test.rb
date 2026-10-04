# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Api::V1::GoogleAuthTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @community = communities(:crow_woods)
  end

  def controller_log
    io = StringIO.new
    original = ActionController::Base.logger
    ActionController::Base.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    ActionController::Base.logger = original
  end

  # The apps send the Google profile along; a member's name and photo don't
  # belong in the server logs. Only these are filtered: "name" elsewhere is
  # a task's or a meal's.
  test "google_auth doesn't log the member's name or photo" do
    log = controller_log do
      post api_v1_google_auth_url,
        params: { name: "Pat Example", image_url: "https://lh3.googleusercontent.com/a/photo", community_domain: @community.domain },
        as: :json
    end

    assert_match "Parameters", log
    assert_no_match "Pat Example", log
    assert_no_match "googleusercontent", log
    assert_match @community.domain, log
  end

  test "google_auth without id_token is rejected even for an existing user's email" do
    post api_v1_google_auth_url,
      params: { email: @user.email, name: @user.name, community_domain: @community.domain },
      as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_nil json["auth_token"]
    assert_nil session[:user_id]
  end

  test "google_auth ignores params and uses the verified token's identity" do
    verified = {
      "email" => @user.email,
      "email_verified" => "true",
      "name" => @user.name,
      "picture" => "https://example.com/avatar.png",
      "sub" => @user.uid
    }

    GoogleIdTokenVerifier.stub(:verify, verified) do
      post api_v1_google_auth_url,
        params: { id_token: "valid-token", email: "attacker@example.com", community_domain: @community.domain },
        as: :json
    end

    assert_response :ok
    json = JSON.parse(response.body)
    assert json["auth_token"].present?
    assert_equal @user.id, json["user"]["id"]
    assert_equal @user.email, json["user"]["email"]
  end

  test "google_auth rejects a token whose email is not verified" do
    unverified = {
      "email" => @user.email,
      "email_verified" => "false",
      "name" => @user.name,
      "sub" => @user.uid
    }

    GoogleIdTokenVerifier.stub(:verify, unverified) do
      post api_v1_google_auth_url,
        params: { id_token: "valid-token", community_domain: @community.domain },
        as: :json
    end

    assert_response :unauthorized
    assert_nil JSON.parse(response.body)["auth_token"]
  end

  test "google_auth rejects an invalid token" do
    GoogleIdTokenVerifier.stub(:verify, nil) do
      post api_v1_google_auth_url,
        params: { id_token: "bogus", community_domain: @community.domain },
        as: :json
    end

    assert_response :unauthorized
    assert_nil JSON.parse(response.body)["auth_token"]
  end

  test "google_auth requires community_domain even for existing users" do
    verified = { "email" => @user.email, "email_verified" => "true", "name" => @user.name, "sub" => @user.uid }

    GoogleIdTokenVerifier.stub(:verify, verified) do
      post api_v1_google_auth_url, params: { id_token: "valid-token" }, as: :json
    end

    assert_response :bad_request
    assert_equal "community_domain_required", JSON.parse(response.body)["error"]
  end

  # --- new accounts need an invitation ---

  def newcomer_claims
    { "email" => "newcomer@example.com", "email_verified" => "true", "name" => "Newcomer", "sub" => "sub-newcomer" }
  end

  test "google_auth refuses to create a new user without a valid invitation" do
    GoogleIdTokenVerifier.stub(:verify, newcomer_claims) do
      assert_no_difference("User.count") do
        post api_v1_google_auth_url, params: { id_token: "valid-token", community_domain: @community.domain }, as: :json
      end
    end

    assert_response :forbidden
    assert_nil JSON.parse(response.body)["auth_token"]
  end

  test "google_auth creates a new user with a valid invitation token" do
    invitation = Invitation.create!

    GoogleIdTokenVerifier.stub(:verify, newcomer_claims) do
      assert_difference("User.count", 1) do
        post api_v1_google_auth_url,
          params: { id_token: "valid-token", community_domain: @community.domain, invitation_token: invitation.token },
          as: :json
      end
    end

    assert_response :ok
    assert JSON.parse(response.body)["auth_token"].present?
    assert_equal @community.id, User.find_by(email: "newcomer@example.com").community_id
  end

  # CON-91: app sign-ups used to get a random password nobody knew, so the
  # Account page asked for a "current password" they'd never had
  test "a member who signs up with Google in the app can set their own password" do
    invitation = Invitation.create!
    GoogleIdTokenVerifier.stub(:verify, newcomer_claims) do
      post api_v1_google_auth_url,
        params: { id_token: "valid-token", community_domain: @community.domain, invitation_token: invitation.token },
        as: :json
    end
    newcomer = User.find_by(email: "newcomer@example.com")
    assert_nil newcomer.password_digest

    get account_path
    assert_select "h3", text: "Set a password to enable email login"
    patch set_password_path, params: { new_password: "a-new-password", new_password_confirmation: "a-new-password" }
    assert newcomer.reload.authenticate("a-new-password")
  end
end
