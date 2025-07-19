require "application_system_test_case"

class LikeButtonsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @post = posts(:two)
    @topic = discussion_topics(:one)
    @comment = comments(:two)
    @topic_comment = topic_comments(:one)

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

    # Like the comment
    find("[data-testid='like-comment-button-#{@comment.id}']").click
    assert find("[data-testid='unlike-comment-button-#{@comment.id}']").visible?

    # Unlike the comment
    find("[data-testid='unlike-comment-button-#{@comment.id}']").click
    assert find("[data-testid='like-comment-button-#{@comment.id}']").visible?
  end
end
