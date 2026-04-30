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

end
