require "application_system_test_case"

class PasswordChangeTest < ApplicationSystemTestCase
  setup do
    # Use separate email user fixtures for tests that modify user data (test isolation)
    @email_user = users(:email_user)
    @email_user_two = users(:email_user_two)
    @email_user_three = users(:email_user_three)
    @email_user_four = users(:email_user_four)
    @oauth_no_password = users(:oauth_no_password)
    @oauth_with_password = users(:one)  # Has both provider and password_digest
  end

  test "email user can change their password" do
    # Sign in as email user (using email/password login)
    visit login_path
    fill_in "Email", with: @email_user.email
    fill_in "Password", with: "testpassword123"
    click_button "Sign in"

    # Debug: Check if login succeeded
    assert_text "Logged in successfully", wait: 5

    # Navigate to account settings
    visit account_path

    # Find and fill out password change form
    within "#password-change-section" do
      fill_in "Current Password", with: "testpassword123"
      fill_in "New Password", with: "newpassword456"
      fill_in "Confirm New Password", with: "newpassword456"
      click_button "Update Password"
    end

    # Verify success message
    assert_text "Password updated successfully"

    # Sign out via avatar dropdown
    find(".dropdown.dropdown-end .avatar").click
    click_button "Logout"

    # Try signing in with old password - should fail
    visit login_path
    fill_in "Email", with: @email_user.email
    fill_in "Password", with: "testpassword123"
    click_button "Sign in"
    assert_text "Invalid email or password"

    # Sign in with new password - should succeed
    fill_in "Email", with: @email_user.email
    fill_in "Password", with: "newpassword456"
    click_button "Sign in"
    assert_text "Logged in successfully"
  end

  test "password change requires correct current password" do
    # Sign in as different email user (test isolation)
    visit login_path
    fill_in "Email", with: @email_user_two.email
    fill_in "Password", with: "testpassword123"
    click_button "Sign in"
    assert_text "Logged in successfully", wait: 5

    # Navigate to account settings
    visit account_path

    # Try to change password with wrong current password
    within "#password-change-section" do
      fill_in "Current Password", with: "wrongpassword"
      fill_in "New Password", with: "newpassword456"
      fill_in "Confirm New Password", with: "newpassword456"
      click_button "Update Password"
    end

    # Should see error message
    assert_text "Current password is incorrect"
  end

  test "password change validates new password requirements" do
    # Sign in as different email user (test isolation)
    visit login_path
    fill_in "Email", with: @email_user_three.email
    fill_in "Password", with: "testpassword123"
    click_button "Sign in"
    assert_text "Logged in successfully", wait: 5

    # Navigate to account settings
    visit account_path
    assert_selector "#password-change-section", wait: 5

    # Try to set password that's too short (less than 6 characters)
    within "#password-change-section" do
      fill_in "Current Password", with: "testpassword123"
      fill_in "New Password", with: "short"
      fill_in "Confirm New Password", with: "short"

      # Remove HTML5 minlength validation to test server-side validation
      page.execute_script("document.querySelector('input[name=\"new_password\"]').removeAttribute('minlength')")
      page.execute_script("document.querySelector('input[name=\"new_password_confirmation\"]').removeAttribute('minlength')")

      click_button "Update Password"
    end

    # Should see validation error in flash alert
    assert_selector ".alert-error", text: "Password is too short", wait: 5
  end

  test "password change requires matching confirmation" do
    # Sign in as different email user (test isolation)
    visit login_path
    fill_in "Email", with: @email_user_four.email
    fill_in "Password", with: "testpassword123"
    click_button "Sign in"
    assert_text "Logged in successfully", wait: 5

    # Navigate to account settings
    visit account_path

    # Try to change password with mismatched confirmation
    within "#password-change-section" do
      fill_in "Current Password", with: "testpassword123"
      fill_in "New Password", with: "newpassword456"
      fill_in "Confirm New Password", with: "differentpassword"

      # Re-enable the submit button (disabled by Stimulus controller on mismatch)
      # and remove HTML5 required validation to test server-side validation
      page.execute_script("document.querySelector('input[type=\"submit\"]').disabled = false")
      page.execute_script("document.querySelector('input[name=\"new_password_confirmation\"]').removeAttribute('required')")

      click_button "Update Password"
    end

    # Should see error message
    assert_text "Password confirmation doesn't match"
  end

  test "OAuth user can set a password for first time" do
    # Sign in as OAuth user without password
    sign_in_as(@oauth_no_password)

    # Navigate to account settings
    visit account_path

    # OAuth users should see option to set password without current password
    within "#password-change-section" do
      assert_no_text "Current Password"
      assert_text "Set a password to enable email login"

      fill_in "New Password", with: "newpassword456"
      fill_in "Confirm New Password", with: "newpassword456"
      click_button "Set Password"
    end

    # Verify success message
    assert_text "Password set successfully"

    # Sign out via avatar dropdown
    find(".dropdown.dropdown-end .avatar").click
    click_button "Logout"

    # Now they should be able to sign in with email and password
    visit login_path
    fill_in "Email", with: @oauth_no_password.email
    fill_in "Password", with: "newpassword456"
    click_button "Sign in"
    assert_text "Logged in successfully"
  end

  test "password change section not shown for OAuth users without password" do
    # Sign in as OAuth user without password
    sign_in_as(@oauth_no_password)

    # Navigate to account settings
    visit account_path

    # Should see option to set password, not change password
    assert_selector "#password-change-section"
    within "#password-change-section" do
      assert_text "Set a password to enable email login"
      assert_no_text "Current Password"
    end
  end

  test "password change section shown for OAuth users with password set" do
    # Sign in as OAuth user who has a password
    sign_in_as(@oauth_with_password)

    # Navigate to account settings
    visit account_path

    # Should see change password form with current password field
    within "#password-change-section" do
      assert_text "Current Password"
      assert_selector "input[type='submit'][value='Update Password']"
    end
  end
end
