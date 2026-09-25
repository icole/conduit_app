require "application_system_test_case"

class UserDeletionTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:admin_user))
    @member = users(:regular_user)
  end

  test "deleting a user asks first, and cancelling keeps them" do
    visit edit_user_url(@member)
    dismiss_confirm(/delete this user/) { click_button "Delete User" }

    assert_current_path edit_user_path(@member)
    assert User.exists?(@member.id)
  end

  test "confirming deletes the user" do
    visit edit_user_url(@member)
    accept_confirm(/delete this user/) { click_button "Delete User" }

    assert_text "User was successfully deleted."
    assert_not User.exists?(@member.id)
  end
end
