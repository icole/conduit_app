require "application_system_test_case"

class PostsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @uncommented_post = posts(:one) # This post has no comments from user one
    @post = posts(:two)
    @user_comment = comments(:two) # This is a comment made by user one on post two

    sign_in_user
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

    within "#post_#{@uncommented_post.id}" do
      assert_selector ".post-actions"
      accept_confirm do
        find("[data-testid='delete-post-button-#{@uncommented_post.id}']").click
      end
    end

    assert_no_selector "#post_#{@uncommented_post.id}"
  end

  test "liking and unliking a post" do
    visit dashboard_index_url

    within "#post_#{@post.id}" do
      assert_selector ".post-actions"
      # Initially the post should show "Like (0)" or "Like (1)" depending on fixtures
      assert_selector "button", text: /👍 Like \(\d+\)/

      # Click the like button
      find("[data-testid='like-button-#{@post.id}']").click

      # Now it should show "Unlike"
      assert_selector "button", text: /👍 Unlike \(\d+\)/

      # Click the unlike button
      find("[data-testid='unlike-button-#{@post.id}']").click

      # Now it should show "Like" again
      assert_selector "button", text: /👍 Like \(\d+\)/
    end
  end

  test "commenting on a post" do
    visit dashboard_index_url

    within "#post_#{@uncommented_post.id}" do
      # Initially the comments section should be hidden
      assert_no_selector ".post-comments"

      # Click the comment button to show the comment form
      find("[data-testid='comment-button-#{@uncommented_post.id}']").click

      # Fill in and submit a new comment
      fill_in "comment_content", with: "This is a test comment."
      click_on "Comment"

      # The comment should now be visible
      assert_selector ".comment-content", text: "This is a test comment."

      # The comments section should no longer have the hidden class
      assert_selector ".post-comments"
    end
  end

  test "comments section remains expanded after page reload if user commented" do
    visit dashboard_index_url

    within "#post_#{@post.id}" do
      # Fill in and submit a new comment
      fill_in "comment_content", with: "This is a test comment for auto-expansion."
      click_on "Comment"
    end

    # Reload the page
    visit dashboard_index_url

    # The comments section should be visible without clicking the comment button
    within "#post_#{@post.id}" do
      assert_selector ".post-comments"
      assert_selector ".comment-content", text: "This is a test comment for auto-expansion."
    end
  end

  test "deleting a comment" do
    visit dashboard_index_url

    within "#post_#{@post.id}" do
      # Ensure the comment exists
      assert_selector ".comment-content", text: @user_comment.content

      # Click the delete button for the comment
      accept_confirm do
        find("[data-testid='delete-comment-button-#{@user_comment.id}']").click
      end

      # The comment should no longer be visible
      assert_no_selector ".comment-content", text: @user_comment.content
    end
  end
end
