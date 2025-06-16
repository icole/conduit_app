require "application_system_test_case"

class PostsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @post = posts(:post_one)

    # Log in
    visit login_url
    fill_in "Email", with: @user.email
    fill_in "Password", with: "password"
    click_on "Log in"
  end

  test "viewing posts on dashboard" do
    visit dashboard_index_url

    assert_selector ".post-content", text: @post.content
  end

  test "creating a new post" do
    visit dashboard_index_url

    click_on "New Post"
    fill_in "post_content", with: "This is a test post created by the system test."
    click_on "Post"

    assert_selector ".post-content", text: "This is a test post created by the system test."
  end

  test "deleting a post" do
    visit dashboard_index_url

    within "#post_#{@post.id}" do
      click_on "🗑️ Delete"
    end

    assert_no_selector "#post_#{@post.id}"
  end
end
