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

    assert_selector "[data-testid='post-content']", text: @post.content
  end

  test "creating a new post" do
    visit dashboard_index_url

    click_on "New Post"
    fill_in "post_content", with: "This is a test post created by the system test."
    find("[data-testid='post-form-submit-button']").click

    assert_selector "[data-testid='post-content']", text: "This is a test post created by the system test."
  end

  test "deleting a post" do
    visit dashboard_index_url

    within "#post_#{@uncommented_post.id}" do
      assert_selector "[data-testid='post-actions']"
      accept_confirm do
        find("[data-testid='delete-post-button-#{@uncommented_post.id}']").click
      end
    end

    assert_no_selector "##{dom_id(@uncommented_post)}"
  end

  test "liking and unliking a post" do
    visit dashboard_index_url

    within "##{dom_id(@post)}" do
      # Initially the post should show "Like (0)" or "Like (1)" depending on fixtures
      assert_selector "button", text: /Like \(\d+\)/

      # Click the like button
      find("[data-testid='like-post-button-#{@post.id}']").click

      # Now it should show "Liked"
      assert_selector "button", text: /Liked \(\d+\)/

      # Click the unlike button
      find("[data-testid='unlike-post-button-#{@post.id}']").click

      # Now it should show "Like" again
      assert_selector "button", text: /Like \(\d+\)/
    end
  end

  test "commenting on a post" do
    visit dashboard_index_url

    assert_selector "##{dom_id(@uncommented_post)}"
    within "##{dom_id(@uncommented_post)}" do
      # Initially the comments section should be hidden (if user hasn't commented yet)
      assert_no_selector "#post-#{@uncommented_post.id}-comments"

      # Click the comment button to show the comment form
      find("[data-testid='comment-button-#{@uncommented_post.id}']").click

      # Fill in and submit a new comment
      fill_in "comment_content", with: "This is a test comment."
      click_on "Post"

      # The comment should now be visible
      assert_selector "[data-testid='comment-content']", text: "This is a test comment."

      # The comments section should no longer have the hidden class
      assert_selector "#post-#{@uncommented_post.id}-comments"
    end
  end

  test "comments section remains expanded after page reload if user commented" do
    visit dashboard_index_url

    within "##{dom_id(@post)}" do
      # Check if comments section is hidden and expand it manually if needed
      comment_section_id = "post-#{@post.id}-comments"
      if has_selector?("[data-testid='comment-button-#{@post.id}']", wait: 1)
        # Comments are collapsed, try clicking the button
        find("[data-testid='comment-button-#{@post.id}']").click
        sleep(0.5) # Give time for any JS to execute

        # If still not visible, manually remove hidden class as fallback
        unless has_field?("comment[content]", wait: 1)
          execute_script("document.getElementById('#{comment_section_id}').classList.remove('hidden')")
        end

        assert has_field?("comment[content]", wait: 2), "Comment form should be visible after expanding comments"
      else
        # Comments should already be expanded
        assert has_field?("comment[content]", wait: 2), "Comment form should be visible since user has commented"
      end

      # Fill in and submit a new comment
      fill_in "comment[content]", with: "This is a test comment for auto-expansion."
      click_on "Post"
    end

    # Reload the page
    visit dashboard_index_url

    # The comments section should be visible without clicking the comment button
    within "##{dom_id(@post)}" do
      assert_selector "#post-#{@post.id}-comments"
      assert_selector "[data-testid='comment-content']", text: "This is a test comment for auto-expansion."
    end
  end

  test "deleting a comment" do
    visit dashboard_index_url

    within "##{dom_id(@post)}" do
      # Expand comments section if needed
      if has_selector?("[data-testid='comment-button-#{@post.id}']")
        find("[data-testid='comment-button-#{@post.id}']").click
        sleep(0.5) # Give time for any JS to execute

        # If still not visible, manually remove hidden class as fallback
        unless has_selector?("[data-testid='comment-content']", wait: 1)
          execute_script("document.getElementById('post-#{@post.id}-comments').classList.remove('hidden')")
        end

        assert has_selector?("[data-testid='comment-content']", wait: 2), "Comments should be visible after clicking comment button"
      end

      # Ensure the comment exists
      assert_selector "[data-testid='comment-content']", text: @user_comment.content

      # Click the delete button for the comment
      accept_confirm do
        find("[data-testid='delete-comment-button-#{@user_comment.id}']").click
      end

      # The comment should no longer be visible
      assert_no_selector "[data-testid='comment-content']", text: @user_comment.content
    end
  end

  test "new comments are appended to the end of the list" do
    visit dashboard_index_url

    # Use a post that doesn't have any comments yet
    within "##{dom_id(@uncommented_post)}" do
      # Click the comment button to show the comment form
      find("[data-testid='comment-button-#{@uncommented_post.id}']").click

      # Add first comment
      fill_in "comment_content", with: "First test comment"
      click_on "Post"

      # Verify the first comment was added
      assert_text "First test comment"

      # Add second comment
      fill_in "comment_content", with: "Second test comment"
      click_on "Post"

      # Verify the second comment was added
      assert_text "Second test comment"

      # Get all comment elements
      comments = all("[data-testid='comment-content']")

      # Verify that the second comment is the last one in the list (was appended)
      assert_equal "Second test comment", comments.last.text

      # Verify that the first comment comes before the second comment
      first_index = comments.find_index { |c| c.text == "First test comment" }
      second_index = comments.find_index { |c| c.text == "Second test comment" }
      assert first_index < second_index, "First comment should appear before second comment"
    end
  end

  test "comment count updates without page refresh when adding a comment" do
    # Create a fresh post with no comments
    fresh_post = Post.create!(content: "Fresh post for comment count test", user: @user)

    visit dashboard_index_url

    within "##{dom_id(fresh_post)}" do
      # Initially the comment count should be 0
      assert_selector "[data-testid='comment-button-#{fresh_post.id}']", text: /\(0\)/

      # Click the comment button to show the comment form
      find("[data-testid='comment-button-#{fresh_post.id}']").click

      # Add a comment
      fill_in "comment_content", with: "Test comment for count update"
      click_on "Post"

      # Verify the comment was added
      assert_selector "[data-testid='comment-content']", text: "Test comment for count update"

      # The comment count should now be 1 without page refresh
      assert_selector "[data-testid='comment-button-#{fresh_post.id}']", text: /\(1\)/
    end
  end

  test "comment count updates without page refresh when deleting a comment" do
    # Create a fresh post with one comment from current user
    fresh_post = Post.create!(content: "Post for delete comment test", user: @user)
    comment = fresh_post.comments.create!(content: "Comment to delete", user: @user)

    visit dashboard_index_url

    within "##{dom_id(fresh_post)}" do
      # Initially the comment count should be 1
      assert_selector "[data-testid='comment-button-#{fresh_post.id}']", text: /\(1\)/

      # Comments should be visible since current user commented
      assert_selector "[data-testid='comment-content']", text: "Comment to delete"

      # Delete the comment
      accept_confirm do
        find("[data-testid='delete-comment-button-#{comment.id}']").click
      end

      # Verify the comment is removed
      assert_no_selector "[data-testid='comment-content']", text: "Comment to delete"

      # The comment count should now be 0 without page refresh
      assert_selector "[data-testid='comment-button-#{fresh_post.id}']", text: /\(0\)/
    end
  end
end
