require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index for regular user and show posts" do
    sign_in_user
    get dashboard_index_url
    assert_response :success
    assert_equal 2, assigns(:posts).count
    assert_not_nil assigns(:post)
  end

  test "should get index for restricted user and not show posts" do
    # Sign in as a restricted user
    sign_in_user(uid: "restricted123", email: "restricted@example.com")

    # Get the signed in user and mark as restricted
    user = User.find_by(email: "restricted@example.com")
    user.update(restricted_access: true)

    get dashboard_index_url
    assert_response :success
    assert_equal 0, assigns(:posts).count
    assert_nil assigns(:post)
  end
end
