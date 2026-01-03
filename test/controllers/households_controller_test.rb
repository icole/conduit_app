# frozen_string_literal: true

require "test_helper"

class HouseholdsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin_user)
    @regular_user = users(:regular_user)
    @household = households(:smith_household)
  end

  # Authentication and authorization tests
  test "should redirect index when not logged in" do
    get households_url
    assert_redirected_to login_url
  end

  test "should redirect index when not admin" do
    sign_in_as(@regular_user)
    get households_url
    assert_redirected_to root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  test "should get index when admin" do
    sign_in_as(@admin_user)
    get households_url
    assert_response :success
  end

  test "should get new when admin" do
    sign_in_as(@admin_user)
    get new_household_url
    assert_response :success
  end

  test "should create household when admin" do
    sign_in_as(@admin_user)
    assert_difference("Household.count") do
      post households_url, params: { household: { name: "New Household" } }
    end
    assert_redirected_to households_path
    assert_equal "Household was successfully created.", flash[:notice]
  end

  test "should not create household with blank name" do
    sign_in_as(@admin_user)
    assert_no_difference("Household.count") do
      post households_url, params: { household: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "should get edit when admin" do
    sign_in_as(@admin_user)
    get edit_household_url(@household)
    assert_response :success
  end

  test "should update household when admin" do
    sign_in_as(@admin_user)
    patch household_url(@household), params: { household: { name: "Updated Name" } }
    assert_redirected_to households_path
    assert_equal "Household was successfully updated.", flash[:notice]
    @household.reload
    assert_equal "Updated Name", @household.name
  end

  test "should update household members when admin" do
    sign_in_as(@admin_user)
    user = users(:one)
    assert_nil user.household_id

    patch household_url(@household), params: {
      household: { name: @household.name, user_ids: [ user.id.to_s, "" ] }
    }

    assert_redirected_to households_path
    user.reload
    assert_equal @household.id, user.household_id
  end

  test "should destroy household when admin" do
    sign_in_as(@admin_user)
    assert_difference("Household.count", -1) do
      delete household_url(@household)
    end
    assert_redirected_to households_path
    assert_equal "Household was successfully deleted.", flash[:notice]
  end

  private

  def sign_in_as(user)
    post login_url, params: { email: user.email, password: "password" }
    assert_equal user.id, session[:user_id], "Failed to sign in as #{user.email}"
  end
end
