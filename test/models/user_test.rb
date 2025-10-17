require "test_helper"
require "ostruct"

class UserTest < ActiveSupport::TestCase
  def setup
    @auth_hash = OpenStruct.new(
      provider: "google_oauth2",
      uid: "123456789",
      info: OpenStruct.new(
        email: "test@example.com",
        name: "Test User",
        image: "https://example.com/avatar.jpg"
      )
    )
  end

  def create_auth_hash(uid, email = "test@example.com", name = "Test User")
    OpenStruct.new(
      provider: "google_oauth2",
      uid: uid,
      info: OpenStruct.new(
        email: email,
        name: name,
        image: "https://example.com/avatar.jpg"
      )
    )
  end

  test "from_omniauth creates new user with valid invitation" do
    invitation = invitations(:user_one_invitation)
    auth_hash = create_auth_hash("new_user_uid", "newuser@example.com", "New User")

    user = User.from_omniauth(auth_hash, invitation.token)
    user.save!

    assert user.persisted?
    assert_equal "newuser@example.com", user.email
    assert_equal "New User", user.name
    assert_equal invitation, user.invitation
  end

  test "from_omniauth raises error for new user without valid invitation in production" do
    # Temporarily set Rails environment to production to test invitation validation
    original_env = Rails.env
    Rails.env = ActiveSupport::EnvironmentInquirer.new("production")

    begin
      auth_hash = create_auth_hash("production_user_uid", "production@example.com", "Production User")
      assert_raises(StandardError, "Access restricted to invited users only") do
        User.from_omniauth(auth_hash, "invalid_token")
      end
    ensure
      Rails.env = original_env
    end
  end

  test "from_omniauth allows existing user to login even with expired invitation" do
    # Create an invitation and a user associated with it
    original_invitation = Invitation.create!(
      token: "original_token_expired",
      expires_at: 2.weeks.from_now
    )

    auth_hash = create_auth_hash("expired_invitation_user", "expired@example.com", "Expired User")

    existing_user = User.create!(
      provider: "google_oauth2",
      uid: "expired_invitation_user",
      email: "expired@example.com",
      name: "Expired User",
      password: "password123",
      invitation: original_invitation
    )

    # Expire the original invitation (simulating replacement)
    original_invitation.update!(expires_at: 1.day.ago)

    # User should still be able to log in
    user = User.from_omniauth(auth_hash)

    assert_equal existing_user, user
    assert user.persisted?
    assert_equal "expired@example.com", user.email
  end

  test "from_omniauth allows existing user to login even when invitation is replaced" do
    # Create an invitation and a user associated with it
    original_invitation = Invitation.create!(
      token: "original_token_replaced",
      expires_at: 2.weeks.from_now
    )

    auth_hash = create_auth_hash("replaced_invitation_user", "replaced@example.com", "Replaced User")

    existing_user = User.create!(
      provider: "google_oauth2",
      uid: "replaced_invitation_user",
      email: "replaced@example.com",
      name: "Replaced User",
      password: "password123",
      invitation: original_invitation
    )

    # Create a new invitation (simulating admin creating a replacement)
    new_invitation = Invitation.create!(
      token: "new_token_replacement",
      expires_at: 2.weeks.from_now
    )

    # User should still be able to log in with their original OAuth credentials
    user = User.from_omniauth(auth_hash)

    assert_equal existing_user, user
    assert user.persisted?
    assert_equal "replaced@example.com", user.email
    # User should still be associated with their original invitation
    assert_equal original_invitation, user.invitation
  end

  test "from_omniauth does not associate existing user with new invitation" do
    # Create an invitation and a user associated with it
    original_invitation = Invitation.create!(
      token: "original_token_not_associated",
      expires_at: 2.weeks.from_now
    )

    auth_hash = create_auth_hash("not_associated_user", "notassociated@example.com", "Not Associated User")

    existing_user = User.create!(
      provider: "google_oauth2",
      uid: "not_associated_user",
      email: "notassociated@example.com",
      name: "Not Associated User",
      password: "password123",
      invitation: original_invitation
    )

    # Create a new invitation
    new_invitation = Invitation.create!(
      token: "new_token_not_associated",
      expires_at: 2.weeks.from_now
    )

    # Try to log in with the new invitation token
    user = User.from_omniauth(auth_hash, new_invitation.token)

    assert_equal existing_user, user
    # User should still be associated with their original invitation, not the new one
    assert_equal original_invitation, user.invitation
    assert_not_equal new_invitation, user.invitation
  end

  test "valid_invitation? returns true for valid invitation" do
    invitation = invitations(:user_one_invitation)
    assert User.valid_invitation?(invitation.token)
  end

  test "valid_invitation? returns false for expired invitation" do
    invitation = invitations(:user_two_invitation)
    assert_not User.valid_invitation?(invitation.token)
  end

  test "valid_invitation? returns false for invalid token" do
    assert_not User.valid_invitation?("invalid_token")
  end
end
