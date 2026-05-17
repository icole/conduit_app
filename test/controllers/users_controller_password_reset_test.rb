# frozen_string_literal: true

require "test_helper"

class UsersControllerPasswordResetTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @user = users(:email_user)
    @community = communities(:crow_woods)
    host! @community.domain || "example.com"
    post login_path, params: { email: @admin.email, password: "password" }
  end

  test "admin can send password reset email for a user" do
    assert_emails 1 do
      post send_password_reset_user_path(@user)
    end
    assert_redirected_to users_path
    assert_match(/reset/, flash[:notice])
    @user.reload
    assert @user.password_reset_sent_at.present?
  end

  test "non-admin cannot send password reset" do
    delete logout_path
    regular = users(:regular_user)
    post login_path, params: { email: regular.email, password: "password" }

    post send_password_reset_user_path(@user)
    assert_redirected_to root_path
  end
end
