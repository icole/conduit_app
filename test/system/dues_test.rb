# frozen_string_literal: true

require "application_system_test_case"

class DuesTest < ApplicationSystemTestCase
  setup do
    @admin_user = users(:admin_user)
    @regular_user = users(:regular_user)
    @household = households(:smith_household)
  end

  test "admin can view dues tracking page" do
    sign_in_as(@admin_user)
    visit dues_path

    assert_selector "h1", text: "Monthly Dues"
    assert_text @household.name
    # Check that month headers are visible
    assert_text "Jan"
    assert_text "Dec"
  end

  test "admin can toggle payment status" do
    sign_in_as(@admin_user)
    visit dues_path

    # Find an unpaid cell and click it
    within "tr", text: @household.name do
      # February is unpaid per fixture
      unpaid_button = find("button", text: "-", match: :first)
      unpaid_button.click
    end

    # Should now show as Paid
    within "tr", text: @household.name do
      assert_selector "button", text: "Paid"
    end
  end

  test "admin can navigate between years" do
    sign_in_as(@admin_user)
    visit dues_path

    current_year = Date.current.year
    assert_text "Monthly Dues - #{current_year}"

    # Navigate to previous year
    click_on "#{current_year - 1}"
    assert_text "Monthly Dues - #{current_year - 1}"

    # Navigate to next year
    click_on "#{current_year}"
    assert_text "Monthly Dues - #{current_year}"
  end

  test "admin can access and update dues settings" do
    sign_in_as(@admin_user)
    visit dues_path

    click_on "Settings"
    assert_selector "h1", text: "Dues Settings"

    fill_in "Monthly Dues Amount", with: "350.00"
    click_on "Save Settings"

    assert_text "Dues settings updated successfully"
    # Verify the value was saved by checking the input field
    assert_selector "input[name='community[monthly_dues_amount]'][value='350.0']"
  end

  test "regular user cannot access dues page" do
    sign_in_as(@regular_user)
    visit dues_path

    assert_text "You are not authorized to access this page"
    assert_current_path root_path
  end

  test "shows message when no households exist" do
    # Delete all households
    Household.destroy_all

    sign_in_as(@admin_user)
    visit dues_path

    assert_text "No households have been created yet"
    assert_link "Create Households First"
  end
end
