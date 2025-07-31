require "test_helper"

class ChoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_user({ uid: @user.uid, name: @user.name, email: @user.email })
  end

  test "should get index" do
    get chores_url
    assert_response :success
  end
end
