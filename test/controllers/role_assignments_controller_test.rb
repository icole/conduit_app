require "test_helper"

class RoleAssignmentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(@user)
    @role = roles(:facilitator)
    @assignment = role_assignments(:maven_holder)
  end

  test "should get new" do
    get new_role_role_assignment_url(@role)
    assert_response :success
  end

  test "should create role assignment" do
    assert_difference("RoleAssignment.count") do
      post role_role_assignments_url(@role), params: { role_assignment: {
        user_id: @user.id,
        assignment_type: "holder",
        starts_at: Date.current,
        ends_at: 6.months.from_now.to_date
      } }
    end
    assert_redirected_to role_url(@role)
  end

  test "should destroy role assignment" do
    assert_difference("RoleAssignment.count", -1) do
      delete role_assignment_url(@assignment)
    end
    assert_redirected_to role_url(@assignment.role)
  end

  private

  def sign_in_as(user)
    post login_url, params: { email: user.email, password: "password" }
    assert_equal user.id, session[:user_id], "Failed to sign in as #{user.email}"
  end
end
