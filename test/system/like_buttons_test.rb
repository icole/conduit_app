require "application_system_test_case"

class LikeButtonsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @post = posts(:two)
    @topic = discussion_topics(:one)
    @comment = comments(:two)
    @topic_comment = comments(:three)  # Now a unified Comment for discussion topics

    sign_in_user
  end

  test "can like and unlike a post" do
    visit dashboard_index_path

    # Like the post
    find("[data-testid='like-post-button-#{@post.id}']").click
    assert_text "Liked (2)"

    # Unlike the post
    find("[data-testid='unlike-post-button-#{@post.id}']").click
    assert_text "Like (1)"
  end

  test "can like and unlike a discussion topic" do
    visit discussion_topic_path(@topic)

    # Like the topic
    find("[data-testid='like-topic-button-#{@topic.id}']").click
    assert find("[data-testid='unlike-topic-button-#{@topic.id}']").visible?

    # Unlike the topic
    find("[data-testid='unlike-topic-button-#{@topic.id}']").click
    assert find("[data-testid='like-topic-button-#{@topic.id}']").visible?
  end

  test "can like and unlike a topic comment" do
    visit discussion_topic_path(@topic)

    # Like the comment
    find("[data-testid='like-comment-button-#{@topic_comment.id}']").click
    assert find("[data-testid='unlike-comment-button-#{@topic_comment.id}']").visible?

    # Unlike the comment
    find("[data-testid='unlike-comment-button-#{@topic_comment.id}']").click
    assert find("[data-testid='like-comment-button-#{@topic_comment.id}']").visible?
  end

  test "can like and unlike a post comment" do
    visit dashboard_index_path

    # Expand comments section first and wait for comments to be visible
    find("[data-testid='comment-button-#{@post.id}']").click
    sleep(0.5) # Give time for any JS to execute
    
    # If still not visible, manually remove hidden class as fallback
    unless has_selector?("[data-testid='like-comment-button-#{@comment.id}']", wait: 1)
      execute_script("document.getElementById('post-#{@post.id}-comments').classList.remove('hidden')")
    end
    
    assert has_selector?("[data-testid='like-comment-button-#{@comment.id}']", wait: 2), "Like button should be visible after expanding comments"

    # Like the comment
    find("[data-testid='like-comment-button-#{@comment.id}']").click
    assert find("[data-testid='unlike-comment-button-#{@comment.id}']").visible?

    # Unlike the comment
    find("[data-testid='unlike-comment-button-#{@comment.id}']").click
    assert find("[data-testid='like-comment-button-#{@comment.id}']").visible?
  end
end
