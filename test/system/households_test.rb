# frozen_string_literal: true

require "application_system_test_case"

class HouseholdsTest < ApplicationSystemTestCase
  setup do
    @admin_user = users(:admin_user)
    @regular_user = users(:regular_user)
    @household = households(:smith_household)
  end

  test "admin can view households list" do
    sign_in_as(@admin_user)
    visit households_path

    assert_selector "h1", text: "Household Management"
    assert_text @household.name
  end

  test "admin can create a new household" do
    sign_in_as(@admin_user)
    visit households_path

    click_on "New Household"
    fill_in "Household Name", with: "The Johnson Family"
    click_on "Create Household"

    assert_text "Household was successfully created"
    assert_text "The Johnson Family"
  end

  test "admin can edit a household" do
    sign_in_as(@admin_user)
    visit households_path

    within "tr", text: @household.name do
      click_on "Edit"
    end

    fill_in "Household Name", with: "Updated Household Name"
    click_on "Update Household"

    assert_text "Household was successfully updated"
    assert_text "Updated Household Name"
  end

  test "admin can delete a household" do
    sign_in_as(@admin_user)
    visit households_path

    within "tr", text: @household.name do
      accept_confirm do
        click_on "Delete"
      end
    end

    assert_text "Household was successfully deleted"
    assert_no_text @household.name
  end

  test "admin can assign users to household" do
    user = users(:one)
    sign_in_as(@admin_user)
    visit edit_household_path(@household)

    assert_selector "label", text: "Members"

    # Check the user checkbox
    check "user_#{user.id}"
    click_on "Update Household"

    assert_text "Household was successfully updated"

    # Verify user is now in the household
    visit households_path
    within "tr", text: @household.name do
      assert_text user.name
    end
  end

  test "regular user cannot access households" do
    sign_in_as(@regular_user)
    visit households_path

    assert_text "You are not authorized to access this page"
    assert_current_path root_path
  end
end
