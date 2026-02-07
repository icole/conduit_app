require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:email_user)
  end

  test "update permits dietary_needs parameter" do
    sign_in_as(@user)

    patch profile_url, params: { user: { name: "Updated Name", dietary_needs: "Vegetarian, no nuts" } }

    assert_response :redirect
    @user.reload
    assert_equal "Vegetarian, no nuts", @user.dietary_needs
  end

  test "update allows clearing dietary_needs" do
    @user.update!(dietary_needs: "Some allergies")
    sign_in_as(@user)

    patch profile_url, params: { user: { name: @user.name, dietary_needs: "" } }

    assert_response :redirect
    @user.reload
    assert_equal "", @user.dietary_needs
  end

  private

  def sign_in_as(user)
    post login_url, params: { email: user.email, password: "testpassword123" }
    assert_equal user.id, session[:user_id], "Failed to sign in as #{user.email}"
  end
end
