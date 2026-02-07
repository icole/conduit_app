require "application_system_test_case"

class ProfileTest < ApplicationSystemTestCase
  setup do
    @oauth_user = users(:one)
    @email_user = users(:email_user_profile)  # Use separate fixture for test isolation
  end

  test "OAuth user can edit their name from account settings" do
    # Sign in as OAuth user
    sign_in_as(@oauth_user)

    # Navigate to account settings
    visit account_path

    # Verify current name is displayed
    assert_text @oauth_user.name

    # Find and click the edit button
    find("a[title='Edit name']").click

    # The edit form should appear in place
    # Clear and enter new name
    new_name = "Updated OAuth User"
    fill_in "user[name]", with: new_name

    # Submit the form
    click_button "Save"

    # Verify the name was updated and we're back to display mode
    assert_text "Updated OAuth User"
    assert_selector "a[title='Edit name']"

    # Verify we're still on account page
    assert_current_path account_path
  end

  test "email user can edit their name from account settings" do
    # Sign in as email user
    visit login_path
    fill_in "Email", with: @email_user.email
    fill_in "Password", with: "testpassword123"
    click_button "Sign in"

    # Debug: Check login succeeded
    assert_text "Logged in successfully", wait: 5

    # Navigate to account settings
    visit account_path

    # Verify current name is displayed
    assert_text @email_user.name

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
    # Sign in as OAuth user
    sign_in_as(@oauth_user)

    visit account_path

    # Click edit
    find("a[title='Edit name']").click

    # Start typing a new name
    fill_in "user[name]", with: "This will be cancelled"

    # Click cancel
    click_link "Cancel"

    # Should be back to display mode with original name
    assert_text @oauth_user.name
    assert_no_text "This will be cancelled"
    assert_selector "a[title='Edit name']"
  end

  test "name validation works when editing" do
    # Sign in as OAuth user
    sign_in_as(@oauth_user)

    visit account_path

    # Click edit
    find("a[title='Edit name']").click

    # Try to save an empty name
    fill_in "user[name]", with: ""
    click_button "Save"

    # Should still be in edit mode due to validation error
    assert_selector "input[name='user[name]']"
  end

  test "user can add dietary needs" do
    sign_in_as(@oauth_user)
    visit account_path

    # Should see the dietary needs section
    assert_text "Dietary Needs"

    # Fill in dietary needs
    fill_in "user[dietary_needs]", with: "Vegetarian, allergic to tree nuts"
    click_button "Save Dietary Needs"

    # Wait for the flash to appear
    assert_text "Dietary needs updated.", wait: 5

    # Verify the field has the saved value
    assert_field "user[dietary_needs]", with: "Vegetarian, allergic to tree nuts"

    # Verify it persisted
    @oauth_user.reload
    assert_equal "Vegetarian, allergic to tree nuts", @oauth_user.dietary_needs
  end

  test "user can update dietary needs" do
    @oauth_user.update!(dietary_needs: "Gluten-free")
    sign_in_as(@oauth_user)
    visit account_path

    # Should see existing value
    assert_field "user[dietary_needs]", with: "Gluten-free"

    # Update it
    fill_in "user[dietary_needs]", with: "Gluten-free, no dairy"
    click_button "Save Dietary Needs"

    assert_text "Dietary needs updated."
    @oauth_user.reload
    assert_equal "Gluten-free, no dairy", @oauth_user.dietary_needs
  end

  test "user can clear dietary needs" do
    @oauth_user.update!(dietary_needs: "Some allergies")
    sign_in_as(@oauth_user)
    visit account_path

    # Clear the field
    fill_in "user[dietary_needs]", with: ""
    click_button "Save Dietary Needs"

    assert_text "Dietary needs updated."
    @oauth_user.reload
    assert_equal "", @oauth_user.dietary_needs
  end
end
