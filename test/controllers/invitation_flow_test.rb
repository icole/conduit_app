# frozen_string_literal: true

require "test_helper"

# An invite link has to work wherever it is opened: the invitee has no session,
# so the tenant can only come from the token itself. Every assertion here uses
# an invitation for other_community while the request host is crow-woods', so a
# tenant resolved from the host would be the wrong one.
class InvitationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @community = communities(:other_community)
    @invitation = ActsAsTenant.with_tenant(@community) { Invitation.create! }
    host! "crowwoods.test"
  end

  test "the accept page opens for a signed-out invitee" do
    get accept_invitation_path(@invitation.token)

    assert_response :success
    assert_equal @invitation.token, session[:invitation_token]
  end

  test "the registration form opens after accepting" do
    get accept_invitation_path(@invitation.token)
    get register_path

    assert_response :success
  end

  test "registering puts the new member in the invitation's community, not the host's" do
    get accept_invitation_path(@invitation.token)

    assert_difference "User.unscoped.count", 1 do
      post register_path, params: { user: {
        name: "Neighbour", email: "neighbour@example.com",
        password: "password123", password_confirmation: "password123"
      } }
    end

    user = ActsAsTenant.without_tenant { User.unscoped.find_by(email: "neighbour@example.com") }
    assert_equal @community.id, user.community_id
    assert_equal @invitation.id, user.invitation_id
  end

  test "an expired invitation is refused" do
    expired = ActsAsTenant.with_tenant(@community) { Invitation.create!(expires_at: 1.day.ago) }

    get accept_invitation_path(expired.token)

    assert_redirected_to login_path
    assert_match(/expired/i, flash[:alert])
  end

  test "an unknown token is refused" do
    get accept_invitation_path("not-a-real-token")

    assert_redirected_to login_path
    assert_match(/invalid/i, flash[:alert])
  end
end
