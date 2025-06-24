require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user1 = users(:one)
    @post = posts(:two)
    @comment = comments(:two)
    sign_in_user({ uid: @user1.uid, name: @user1.name, email: @user1.email })
  end

  test "should create comment" do
    assert_difference("Comment.count", 1) do
      post post_comments_url(post_id: @post.id), params: { comment: { content: "This is a test comment" } }
    end

    assert_redirected_to dashboard_index_url
  end

  test "should destroy comment" do
    assert_difference("Comment.count", -1) do
      delete post_comment_url(post_id: @post.id, id: @comment.id)
    end

    assert_redirected_to dashboard_index_url
  end
end
