require "test_helper"

class AccountControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:email_user)
    sign_in_as(@user)
  end

  private

  def sign_in_as(user)
    post login_path, params: { email: user.email, password: "testpassword123" }
    assert_equal user.id, session[:user_id], "Failed to sign in as #{user.email}"
  end

  test "update_password rejects mismatched confirmation" do
    patch update_password_path, params: {
      current_password: "testpassword123",
      new_password: "newpassword456",
      new_password_confirmation: "differentpassword"
    }

    assert_redirected_to account_path
    assert_match(/confirmation/i, flash[:alert])
  end

  test "update_password rejects incorrect current password" do
    patch update_password_path, params: {
      current_password: "wrongpassword",
      new_password: "newpassword456",
      new_password_confirmation: "newpassword456"
    }

    assert_redirected_to account_path
    follow_redirect!
    assert_match "Current password is incorrect", response.body
  end

  test "update_password succeeds with valid params" do
    patch update_password_path, params: {
      current_password: "testpassword123",
      new_password: "newpassword456",
      new_password_confirmation: "newpassword456"
    }

    assert_redirected_to account_path
    follow_redirect!
    assert_match "Password updated successfully", response.body

    # Verify the password was actually changed
    @user.reload
    assert @user.authenticate("newpassword456")
  end
end
