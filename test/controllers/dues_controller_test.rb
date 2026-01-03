# frozen_string_literal: true

require "test_helper"

class DuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin_user)
    @regular_user = users(:regular_user)
    @household = households(:smith_household)
  end

  # Authentication and authorization tests
  test "should redirect index when not logged in" do
    get dues_url
    assert_redirected_to login_url
  end

  test "should redirect index when not admin" do
    sign_in_as(@regular_user)
    get dues_url
    assert_redirected_to root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "should get index when admin" do
    sign_in_as(@admin_user)
    get dues_url
    assert_response :success
  end

  test "should get index with year parameter" do
    sign_in_as(@admin_user)
    get dues_url(year: 2025)
    assert_response :success
  end

  test "should toggle payment status from unpaid to paid" do
    sign_in_as(@admin_user)
    household = households(:empty_household)

    assert_difference("HouseholdDuesPayment.count") do
      post toggle_dues_url(household_id: household.id, year: 2026, month: 3)
    end

    payment = HouseholdDuesPayment.find_by(household: household, year: 2026, month: 3)
    assert payment.paid
  end

  test "should toggle payment status from paid to unpaid" do
    sign_in_as(@admin_user)
    payment = household_dues_payments(:smith_january_paid)
    assert payment.paid

    post toggle_dues_url(household_id: payment.household_id, year: payment.year, month: payment.month)

    payment.reload
    assert_not payment.paid
  end

  test "should redirect toggle when not admin" do
    sign_in_as(@regular_user)
    post toggle_dues_url(household_id: @household.id, year: 2026, month: 1)
    assert_redirected_to root_path
  end

  test "should get settings when admin" do
    sign_in_as(@admin_user)
    get settings_dues_url
    assert_response :success
  end

  test "should redirect settings when not admin" do
    sign_in_as(@regular_user)
    get settings_dues_url
    assert_redirected_to root_path
  end

  test "should update settings when admin" do
    sign_in_as(@admin_user)
    patch settings_dues_url, params: { community: { monthly_dues_amount: 250.00 } }
    assert_redirected_to settings_dues_path
    assert_equal "Dues settings updated successfully.", flash[:notice]

    communities(:crow_woods).reload
    assert_equal 250.00, communities(:crow_woods).monthly_dues_amount.to_f
  end

  private

  def sign_in_as(user)
    post login_url, params: { email: user.email, password: "password" }
    assert_equal user.id, session[:user_id], "Failed to sign in as #{user.email}"
  end
end
