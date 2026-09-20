require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user1 = users(:one)
    @meal = meals(:upcoming_meal)
    @comment = comments(:two) # on upcoming_meal
    sign_in_user({ uid: @user1.uid, name: @user1.name, email: @user1.email })
  end

  test "should create comment" do
    assert_difference("Comment.count", 1) do
      post meal_comments_url(@meal), params: { comment: { content: "This is a test comment" } }, headers: { "Accept" => "text/html" }
    end

    assert_redirected_to meal_url(@meal)
  end

  test "should destroy comment" do
    assert_difference("Comment.count", -1) do
      delete meal_comment_url(@meal, @comment), headers: { "Accept" => "text/html" }
    end

    assert_redirected_to meal_url(@meal)
  end
end
