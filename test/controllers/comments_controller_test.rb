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
      post post_comments_url(@post), params: { comment: { content: "This is a test comment" } }, headers: { "Accept" => "text/html" }
    end

    assert_response :redirect
  end

  test "should destroy comment" do
    assert_difference("Comment.count", -1) do
      delete post_comment_url(@post, @comment), headers: { "Accept" => "text/html" }
    end

    assert_response :redirect
  end
end
