require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in_user
    get dashboard_index_url
    assert_response :success
  end
end
