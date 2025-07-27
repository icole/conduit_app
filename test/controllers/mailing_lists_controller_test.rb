require "test_helper"

class MailingListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    timestamp = Time.current.to_i
    @admin = User.create!(
      name: "Admin User",
      email: "admin#{timestamp}@example.com",
      provider: "google_oauth2",
      uid: "admin#{timestamp}",
      password: "password123",
      admin: true
    )
    @regular_user = User.create!(
      name: "Regular User",
      email: "user#{timestamp}@example.com",
      provider: "google_oauth2",
      uid: "user#{timestamp}",
      password: "password123",
      admin: false
    )
    @mailing_list = MailingList.create!(name: "test-list-#{timestamp}", description: "Test mailing list")
  end

  test "should get index when admin" do
    sign_in_as(@admin)
    get mailing_lists_path
    assert_response :success
    assert_includes response.body, "Mailing Lists"
  end

  test "should redirect non-admin users" do
    sign_in_as(@regular_user)
    get mailing_lists_path
    assert_redirected_to root_path
  end

  test "should redirect to login when not authenticated" do
    get mailing_lists_path
    assert_redirected_to login_path
  end

  test "should get show when admin" do
    sign_in_as(@admin)
    get mailing_list_path(@mailing_list)
    assert_response :success
    assert_includes response.body, @mailing_list.name
  end

  test "should get new when admin" do
    sign_in_as(@admin)
    get new_mailing_list_path
    assert_response :success
    assert_includes response.body, "New Mailing List"
  end

  test "should create mailing list when admin" do
    sign_in_as(@admin)

    assert_difference("MailingList.count") do
      post mailing_lists_path, params: {
        mailing_list: {
          name: "new-list-#{Time.current.to_i}",
          description: "A new test list",
          active: true
        }
      }
    end

    assert_redirected_to mailing_list_path(MailingList.last)
  end

  test "should get edit when admin" do
    sign_in_as(@admin)
    get edit_mailing_list_path(@mailing_list)
    assert_response :success
    assert_includes response.body, "Edit Mailing List"
  end

  test "should update mailing list when admin" do
    sign_in_as(@admin)
    patch mailing_list_path(@mailing_list), params: {
      mailing_list: {
        description: "Updated description"
      }
    }
    assert_redirected_to @mailing_list
    @mailing_list.reload
    assert_equal "Updated description", @mailing_list.description
  end

  test "should destroy mailing list when admin" do
    sign_in_as(@admin)

    assert_difference("MailingList.count", -1) do
      delete mailing_list_path(@mailing_list)
    end

    assert_redirected_to mailing_lists_path
  end

  test "should add member when admin" do
    sign_in_as(@admin)

    assert_difference("@mailing_list.users.count") do
      post add_member_mailing_list_path(@mailing_list), params: { user_id: @regular_user.id }
    end

    assert_redirected_to @mailing_list
    assert @mailing_list.member?(@regular_user)
  end

  test "should remove member when admin" do
    sign_in_as(@admin)
    @mailing_list.add_user(@regular_user)

    assert_difference("@mailing_list.users.count", -1) do
      delete remove_member_mailing_list_path(@mailing_list), params: { user_id: @regular_user.id }
    end

    assert_redirected_to @mailing_list
    assert_not @mailing_list.member?(@regular_user)
  end

  private

  def sign_in_as(user)
    # Use the existing test helper with user-specific attributes
    sign_in_user(name: user.name, email: user.email, uid: user.uid)
  end
end
