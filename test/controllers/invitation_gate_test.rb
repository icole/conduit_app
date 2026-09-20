# frozen_string_literal: true

require "test_helper"

# The invitation gate is what keeps strangers out of a community. These tests
# exercise the real check - there must be no environment-based bypass.
class InvitationGateTest < ActionDispatch::IntegrationTest
  NEW_ACCOUNT = {
    name: "Stranger", email: "stranger@example.com",
    password: "password123", password_confirmation: "password123"
  }.freeze

  setup do
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: "brand-new-uid",
      info: { name: "Stranger", email: "stranger@example.com" }
    )
  end

  # --- email/password registration ---

  test "registration page requires an accepted invitation" do
    get register_path
    assert_redirected_to login_path
    assert_match(/invitation/i, flash[:alert])
  end

  test "registration refuses to create a user without an invitation" do
    assert_no_difference("User.count") do
      post register_path, params: { user: NEW_ACCOUNT }
    end
    assert_redirected_to login_path
  end

  test "registration works after accepting a valid invitation" do
    invitation = Invitation.create!
    get accept_invitation_path(invitation.token)

    assert_difference("User.count", 1) do
      post register_path, params: { user: NEW_ACCOUNT }
    end
    assert_redirected_to root_path
    assert_equal invitation, User.find_by(email: "stranger@example.com").invitation
  end

  test "registration refuses an expired invitation" do
    invitation = Invitation.create!(expires_at: 1.day.ago)
    get accept_invitation_path(invitation.token)

    assert_no_difference("User.count") do
      post register_path, params: { user: NEW_ACCOUNT }
    end
    assert_redirected_to login_path
  end

  # --- Google sign-in on the web ---

  test "google sign-in for an unknown account requires an invitation" do
    assert_no_difference("User.count") do
      get "/auth/google_oauth2/callback"
    end
    assert_redirected_to login_path
    assert_match(/invit/i, flash[:alert])
    assert_nil session[:user_id]
  end

  test "google sign-in for an unknown account works after accepting an invitation" do
    invitation = Invitation.create!
    get accept_invitation_path(invitation.token)

    assert_difference("User.count", 1) do
      get "/auth/google_oauth2/callback"
    end
    assert_redirected_to root_path
    assert_equal invitation, User.find_by(uid: "brand-new-uid").invitation
  end

  test "existing google accounts sign in without an invitation" do
    user = users(:one)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: user.uid, info: { name: user.name, email: user.email }
    )

    assert_no_difference("User.count") do
      get "/auth/google_oauth2/callback"
    end
    assert_equal user.id, session[:user_id]
  end
end
