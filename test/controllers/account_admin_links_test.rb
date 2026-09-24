# frozen_string_literal: true

require "test_helper"

# The native apps hide the web navbar, so the Account page is the only way an
# admin on a phone can reach the admin screens.
class AccountAdminLinksTest < ActionDispatch::IntegrationTest
  def sign_in(user, password: "testpassword123")
    post login_path, params: { email: user.email, password: password }
    assert_equal user.id, session[:user_id]
  end

  test "an admin sees links to the admin screens" do
    sign_in users(:admin_user), password: "password"
    get account_path

    assert_response :success
    assert_select "a[href=?]", invitations_path
    assert_select "a[href=?]", users_path
    assert_select "a[href=?]", households_path
  end

  test "a non-admin sees none of them" do
    sign_in users(:email_user)
    get account_path

    assert_response :success
    assert_select "a[href=?]", invitations_path, count: 0
    assert_select "a[href=?]", users_path, count: 0
  end

  test "a super admin also sees the cross-community page" do
    sign_in users(:super_admin_user)
    get account_path

    assert_select "a[href=?]", admin_communities_path
  end

  test "an ordinary admin does not see the cross-community page" do
    sign_in users(:admin_user), password: "password"
    get account_path

    assert_select "a[href=?]", admin_communities_path, count: 0
  end
end
