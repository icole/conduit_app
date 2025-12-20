require "application_system_test_case"

class PasswordChangeTest < ApplicationSystemTestCase
  setup do
    # Use the fixture community (matches localhost routing in dev/test)
    @community = communities(:crow_woods)
    ActsAsTenant.current_tenant = @community
  end

  test "email user can change their password" do
    # Create an email-based user (no provider)
    @user = User.create!(
      name: "Email User",
      email: "emailuser@example.com",
      password: "oldpassword123",
      password_confirmation: "oldpassword123",
      community: @community
    )

    # Sign in as email user
    visit login_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "oldpassword123"
    click_button "Sign in"

    # Navigate to account settings
    visit account_path

    # Find and fill out password change form
    within "#password-change-section" do
      fill_in "Current Password", with: "oldpassword123"
      fill_in "New Password", with: "newpassword456"
      fill_in "Confirm New Password", with: "newpassword456"
      click_button "Update Password"
    end

    # Verify success message
    assert_text "Password updated successfully"

    # Sign out
    click_button "Sign out"

    # Try signing in with old password - should fail
    visit login_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "oldpassword123"
    click_button "Sign in"
    assert_text "Invalid email or password"

    # Sign in with new password - should succeed
    fill_in "Email", with: @user.email
    fill_in "Password", with: "newpassword456"
    click_button "Sign in"
    assert_text "Welcome back"
  end

  test "password change requires correct current password" do
    # Create an email-based user
    @user = User.create!(
      name: "Email User",
      email: "emailuser@example.com",
      password: "correctpassword",
      password_confirmation: "correctpassword",
      community: @community
    )

    # Sign in
    visit login_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "correctpassword"
    click_button "Sign in"

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
    # Create an email-based user
    @user = User.create!(
      name: "Email User",
      email: "emailuser@example.com",
      password: "validpassword",
      password_confirmation: "validpassword",
      community: @community
    )

    # Sign in
    visit login_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "validpassword"
    click_button "Sign in"

    # Navigate to account settings
    visit account_path

    # Try to set password that's too short (less than 6 characters)
    within "#password-change-section" do
      fill_in "Current Password", with: "validpassword"
      fill_in "New Password", with: "short"
      fill_in "Confirm New Password", with: "short"
      click_button "Update Password"
    end

    # Should see validation error
    assert_text "Password is too short (minimum is 6 characters)"
  end

  test "password change requires matching confirmation" do
    # Create an email-based user
    @user = User.create!(
      name: "Email User",
      email: "emailuser@example.com",
      password: "validpassword",
      password_confirmation: "validpassword",
      community: @community
    )

    # Sign in
    visit login_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "validpassword"
    click_button "Sign in"

    # Navigate to account settings
    visit account_path

    # Try to change password with mismatched confirmation
    within "#password-change-section" do
      fill_in "Current Password", with: "validpassword"
      fill_in "New Password", with: "newpassword456"
      fill_in "Confirm New Password", with: "differentpassword"
      click_button "Update Password"
    end

    # Should see error message
    assert_text "Password confirmation doesn't match"
  end

  test "OAuth user can set a password for first time" do
    # Sign in as OAuth user (creates user with no password)
    sign_in_user

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

    # Sign out
    click_button "Sign out"

    # Now they should be able to sign in with email and password
    visit login_path
    fill_in "Email", with: "test@example.com" # Default OAuth user email
    fill_in "Password", with: "newpassword456"
    click_button "Sign in"
    assert_text "Welcome back"
  end

  test "password change section not shown for OAuth users without password" do
    # Sign in as OAuth user
    sign_in_user

    # Navigate to account settings
    visit account_path

    # Should see option to set password, not change password
    assert_selector "#password-change-section"
    within "#password-change-section" do
      assert_text "Set Password"
      assert_no_text "Change Password"
    end
  end

  test "password change section shown for OAuth users with password set" do
    # Create an OAuth user with a password already set
    @user = User.create!(
      name: "OAuth User with Password",
      email: "oauth.password@example.com",
      provider: "google_oauth2",
      uid: "987654321",
      password: "existingpassword",
      password_confirmation: "existingpassword",
      community: @community
    )

    # Sign in as this user via OAuth mock
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "987654321",
      info: {
        name: "OAuth User with Password",
        email: "oauth.password@example.com"
      }
    )
    visit "/auth/google_oauth2/callback"

    # Navigate to account settings
    visit account_path

    # Should see change password form with current password field
    within "#password-change-section" do
      assert_text "Change Password"
      assert_text "Current Password"
    end
  end
end
