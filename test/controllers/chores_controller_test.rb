require "test_helper"

class ChoresControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get chores_index_url
    assert_response :success
  end
end
