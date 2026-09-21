# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @user = users(:unverified_user)
  end

  def sign_in(user)
    post login_path, params: { email: user.email, password: "testpassword123" }
    assert_equal user.id, session[:user_id]
  end

  test "registration sends a verification email and the new user is unverified" do
    invitation = Invitation.create!
    get accept_invitation_path(invitation.token)

    assert_enqueued_emails 1 do
      post register_path, params: { user: { name: "Newbie", email: "newbie@example.com",
        password: "password123", password_confirmation: "password123" } }
    end
    assert_not User.find_by(email: "newbie@example.com").email_verified?
  end

  test "visiting the verification link verifies the user, once" do
    @user.update!(email_verification_sent_at: Time.current)
    token = JwtService.generate_email_verification_token(@user)

    get verify_email_path(token)
    assert_redirected_to root_path
    assert @user.reload.email_verified?

    get verify_email_path(token)
    assert_redirected_to root_path
    assert_match(/invalid|expired/i, flash[:alert])
  end

  test "resend sends a fresh verification email to the signed-in user" do
    sign_in @user

    assert_enqueued_emails 1 do
      post resend_email_verification_path
    end
    assert_redirected_to root_path
  end

  test "unverified users see a verification banner; verified users do not" do
    sign_in @user
    get dashboard_index_url
    assert_match(/verify your email/i, response.body)

    delete logout_path
    sign_in users(:email_user)
    get dashboard_index_url
    assert_no_match(/verify your email/i, response.body)
  end

  test "unverified users cannot get a Stream token" do
    token = JwtService.generate_auth_token(@user)
    StreamChatClient.stub :configured?, true do
      get api_v1_stream_token_url, headers: { "Authorization" => "Bearer #{token}" }, as: :json
    end
    assert_response :forbidden
    assert_equal "email_unverified", JSON.parse(response.body)["error"]

    StreamChatClient.stub :configured?, true do
      get token_chat_index_url, headers: { "Authorization" => "Bearer #{token}" }, as: :json
    end
    assert_response :forbidden
    assert_equal "email_unverified", JSON.parse(response.body)["error"]
  end

  test "unverified users cannot get a Liveblocks token" do
    sign_in @user
    post api_liveblocks_auth_url, params: { room: "document:1" }, as: :json
    assert_response :forbidden
    assert_equal "email_unverified", JSON.parse(response.body)["error"]
  end

  test "unverified admins cannot create invitations" do
    @user.update!(admin: true)
    sign_in @user

    get new_invitation_path
    assert_redirected_to root_path
    assert_match(/verify/i, flash[:alert])
  end
end
