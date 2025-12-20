require "application_system_test_case"

class ProfileTest < ApplicationSystemTestCase
  setup do
    # Create a community for testing
    @community = Community.create!(
      name: "Test Community",
      slug: "test-community"
    )
    ActsAsTenant.current_tenant = @community
  end

  test "OAuth user can edit their name from account settings" do
    # Sign in as OAuth user
    sign_in_user  # Signs in as default test user

    # Navigate to account settings
    visit account_path

    # Verify current name is displayed (default test user)
    assert_text "Test User"

    # Find and click the edit button
    find("a[title='Edit name']").click

    # The edit form should appear in place
    # Clear and enter new name
    new_name = "Updated Test User"
    fill_in "user[name]", with: new_name

    # Submit the form
    click_button "Save"

    # Verify the name was updated and we're back to display mode
    assert_text "Updated Test User"
    assert_selector "a[title='Edit name']"

    # Verify we're still on account page
    assert_current_path account_path
  end

  test "email user can edit their name from account settings" do
    # Create an email-based user (no provider)
    @user = User.create!(
      name: "Email User",
      email: "emailuser@example.com",
      password: "password123",
      password_confirmation: "password123",
      community: @community
    )

    # Sign in as email user
    visit login_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"

    # Navigate to account settings
    visit account_path

    # Verify current name is displayed
    assert_text "Email User"

    # Find and click the edit button
    find("a[title='Edit name']").click

    # The edit form should appear in place
    # Clear and enter new name
    new_name = "Updated Email User"
    fill_in "user[name]", with: new_name

    # Submit the form
    click_button "Save"

    # Verify the name was updated and we're back to display mode
    assert_text "Updated Email User"
    assert_selector "a[title='Edit name']"

    # Verify we're still on account page
    assert_current_path account_path
  end

  test "user can cancel editing their name" do
    # Sign in first
    sign_in_user

    visit account_path

    # Click edit
    find("a[title='Edit name']").click

    # Start typing a new name
    fill_in "user[name]", with: "This will be cancelled"

    # Click cancel
    click_link "Cancel"

    # Should be back to display mode with original name
    assert_text "Test User"
    assert_no_text "This will be cancelled"
    assert_selector "a[title='Edit name']"
  end

  test "name validation works when editing" do
    # Sign in first
    sign_in_user

    visit account_path

    # Click edit
    find("a[title='Edit name']").click

    # Try to save an empty name
    fill_in "user[name]", with: ""
    click_button "Save"

    # Should still be in edit mode due to validation error
    assert_selector "input[name='user[name]']"
  end
end
