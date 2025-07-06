require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invitation = invitations(:user_one_invitation)
    @used_invitation = invitations(:user_two_invitation)
    @admin_user = users(:admin_user)
    @regular_user = users(:regular_user)
  end

  # Authentication and authorization tests
  test "should redirect new when not logged in" do
    get new_invitation_url
    assert_redirected_to login_url
  end

  test "should redirect new when not admin" do
    sign_in_as(@regular_user)
    get new_invitation_url
    assert_redirected_to root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "should get new when admin and no active invitations" do
    # Mark all invitations as expired
    @invitation.update(expires_at: 1.day.ago)
    @used_invitation.update(expires_at: 1.day.ago)

    sign_in_as(@admin_user)
    get new_invitation_url
    assert_response :success
  end

  test "should redirect new to index when active invitation exists" do
    sign_in_as(@admin_user)
    # Since user_one_invitation is active (expires in the future)
    get new_invitation_url
    assert_redirected_to invitations_path
  end

  # Create tests
  test "should redirect create when not logged in" do
    post invitations_url, params: { invitation: { expires_at: 2.weeks.from_now } }
    assert_redirected_to login_url
  end

  test "should redirect create when not admin" do
    sign_in_as(@regular_user)
    post invitations_url, params: { invitation: { expires_at: 2.weeks.from_now } }
    assert_redirected_to root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "should create invitation when admin" do
    # First, let's mark the existing invitation as expired
    @invitation.update(expires_at: 1.day.ago)

    sign_in_as(@admin_user)
    assert_difference("Invitation.count") do
      post invitations_url, params: { invitation: { expires_at: 2.weeks.from_now } }
    end
    assert_redirected_to invitations_path
    assert_equal "New invitation link was successfully created.", flash[:notice]
  end

  test "should set default expiration when none provided" do
    # First, let's mark the existing invitation as expired
    @invitation.update(expires_at: 1.day.ago)

    sign_in_as(@admin_user)
    post invitations_url, params: { invitation: { expires_at: "" } }

    # Get the most recent invitation
    new_invitation = Invitation.order(created_at: :desc).first
    # Check that expiration was set (default is 2 weeks)
    assert_not_nil new_invitation.expires_at
    assert new_invitation.expires_at > Time.current
  end

  # Index tests
  test "should redirect index when not logged in" do
    get invitations_url
    assert_redirected_to login_url
  end

  test "should redirect index when not admin" do
    sign_in_as(@regular_user)
    get invitations_url
    assert_redirected_to root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "should get index when admin" do
    sign_in_as(@admin_user)
    get invitations_url
    assert_response :success
    assert_not_nil assigns(:active_invitation)
  end

  # Accept tests
  test "should accept valid invitation" do
    get accept_invitation_url(@invitation.token)
    assert_response :success
    assert_equal @invitation.token, session[:invitation_token]
  end

  test "should reject expired invitation" do
    # Update the invitation to be expired
    @invitation.update(expires_at: 1.day.ago)

    get accept_invitation_url(@invitation.token)
    assert_redirected_to login_path
    assert_equal "This invitation link has expired.", flash[:alert]
    assert_nil session[:invitation_token]
  end

  test "should reject invalid invitation token" do
    get accept_invitation_url("invalid_token")
    assert_redirected_to login_path
    assert_equal "Invalid invitation link.", flash[:alert]
    assert_nil session[:invitation_token]
  end

  private

  # Helper method for signing in users during tests
  def sign_in_as(user)
    post login_url, params: { email: user.email, password: "password" }
    # Check that we're actually signed in
    assert_equal user.id, session[:user_id], "Failed to sign in as #{user.email}"
  end
end
