# frozen_string_literal: true

require "test_helper"

class Admin::CommunitiesControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @super_admin = users(:super_admin_user)
    @community_admin = users(:admin_user)
    @pending = communities(:pending_community)
  end

  def sign_in(user, password: "testpassword123")
    post login_path, params: { email: user.email, password: password }
    assert_equal user.id, session[:user_id]
  end

  # --- access ---

  test "a super admin sees every community, whatever tenant they belong to" do
    sign_in @super_admin
    get admin_communities_path

    assert_response :success
    Community.pluck(:name).each { |name| assert_match name, response.body }
  end

  test "a community admin who is not a super admin is refused" do
    sign_in @community_admin, password: "password"
    get admin_communities_path

    assert_response :forbidden
  end

  test "a signed-out visitor is sent to log in" do
    get admin_communities_path
    assert_redirected_to login_path
  end

  # --- actions ---

  test "approve activates a pending community and emails its admins" do
    sign_in @super_admin

    assert_enqueued_emails 1 do
      post approve_admin_community_path(@pending)
    end

    assert_redirected_to admin_communities_path
    assert @pending.reload.active?
  end

  test "suspend suspends a community and revokes its members' tokens" do
    sign_in @super_admin
    community = communities(:other_community)
    member = ActsAsTenant.with_tenant(community) { User.order(:id).first }
    before = member.token_version

    post suspend_admin_community_path(community)

    assert_redirected_to admin_communities_path
    assert community.reload.suspended?
    assert_equal before + 1, member.reload.token_version
  end

  test "toggling a feature flag flips it" do
    sign_in @super_admin
    assert_not @pending.chat_enabled?

    post set_flag_admin_community_path(@pending), params: { flag: "chat_enabled", value: "true" }

    assert_redirected_to admin_communities_path
    assert @pending.reload.chat_enabled?
  end

  test "an unknown flag is rejected" do
    sign_in @super_admin

    post set_flag_admin_community_path(@pending), params: { flag: "sudo", value: "true" }

    assert_redirected_to admin_communities_path
    assert_match(/unknown/i, flash[:alert])
  end

  test "a community admin cannot approve or suspend" do
    sign_in @community_admin, password: "password"

    post approve_admin_community_path(@pending)
    assert_response :forbidden
    assert @pending.reload.pending?
  end

  test "actions are recorded against the acting user for the audit trail" do
    sign_in @super_admin
    post approve_admin_community_path(@pending)

    version = PaperTrail::Version.where(item_type: "Community", item_id: @pending.id).last
    assert_equal @super_admin.id.to_s, version.whodunnit
  end
end
