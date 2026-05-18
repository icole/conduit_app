require "test_helper"

class RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @community = communities(:crow_woods)
    ActsAsTenant.current_tenant = @community
    @user = users(:one)
    sign_in_user({ uid: @user.uid, name: @user.name, email: @user.email })
    ActsAsTenant.current_tenant = @community
    @role = roles(:garden_maven)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "should get index" do
    get roles_url
    assert_response :success
    assert_select "h1", /Roles/
  end

  test "should get show" do
    get role_url(@role)
    assert_response :success
    assert_select "h1", @role.title
  end

  test "should get new" do
    get new_role_url
    assert_response :success
  end

  test "should create role" do
    assert_difference("Role.count") do
      post roles_url, params: { role: {
        title: "New Test Role",
        role_type: "role",
        group: "community",
        duties: "Do the thing",
        term_length_months: 6
      } }
    end
    new_role = Role.unscoped.order(created_at: :desc).first
    assert_redirected_to role_url(new_role)
  end

  test "should get edit" do
    get edit_role_url(@role)
    assert_response :success
  end

  test "should update role" do
    patch role_url(@role), params: { role: { title: "Updated Title" } }
    assert_redirected_to role_url(@role)
    @role.reload
    assert_equal "Updated Title", @role.title
  end

  test "should soft delete role" do
    assert_difference("Role.count", -1) do
      delete role_url(@role)
    end
    assert_redirected_to roles_url
    assert Role.with_discarded.find(@role.id).discarded?
  end

  test "should require authentication" do
    delete logout_url
    get roles_url
    assert_redirected_to login_url
  end
end
