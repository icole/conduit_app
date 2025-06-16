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

  test "liking and unliking a post" do
    visit dashboard_index_url

    within "#post_#{@post.id}" do
      # Initially the post should show "Like (0)" or "Like (1)" depending on fixtures
      assert_selector "button", text: /👍 Like \(\d+\)/

      # Click the like button
      click_on /👍 Like \(\d+\)/

      # Now it should show "Unlike"
      assert_selector "button", text: /👍 Unlike \(\d+\)/

      # Click the unlike button
      click_on /👍 Unlike \(\d+\)/

      # Now it should show "Like" again
      assert_selector "button", text: /👍 Like \(\d+\)/
    end
  end

  test "commenting on a post" do
    visit dashboard_index_url

    within "#post_#{@post.id}" do
      # Initially the comments section should be hidden
      assert_selector ".post-comments.hidden"

      # Click the comment button to show the comment form
      click_on /💬 Comment \(\d+\)/

      # Fill in and submit a new comment
      fill_in "comment_content", with: "This is a test comment."
      click_on "Comment"

      # The comment should now be visible
      assert_selector ".comment-content", text: "This is a test comment."

      # The comments section should no longer have the hidden class
      assert_no_selector ".post-comments.hidden"
    end
  end

  test "comments section remains expanded after page reload if user commented" do
    visit dashboard_index_url

    within "#post_#{@post.id}" do
      # Click the comment button to show the comment form
      click_on /💬 Comment \(\d+\)/

      # Fill in and submit a new comment
      fill_in "comment_content", with: "This is a test comment for auto-expansion."
      click_on "Comment"
    end

    # Reload the page
    visit dashboard_index_url

    # The comments section should be visible without clicking the comment button
    within "#post_#{@post.id}" do
      assert_no_selector ".post-comments.hidden"
      assert_selector ".comment-content", text: "This is a test comment for auto-expansion."
    end
  end
end
