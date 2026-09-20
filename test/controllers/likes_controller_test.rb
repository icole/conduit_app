require "test_helper"

class LikesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user1 = users(:one)
    @meal = meals(:upcoming_meal)
    @comment = comments(:two)  # on upcoming_meal, liked by user two only
    @like = likes(:one)        # user one's like on comments(:one), which is on needs_cook
    sign_in_user({ uid: @user1.uid, name: @user1.name, email: @user1.email })
  end

  test "should get create" do
    assert_difference("Like.count", 1) do
      post meal_comment_likes_url(@meal, @comment)
    end

    assert_redirected_to meal_url(@meal)
  end

  test "should get destroy" do
    meal = meals(:needs_cook)

    assert_difference("Like.count", -1) do
      delete meal_comment_like_url(meal, comments(:one), @like)
    end

    assert_redirected_to meal_url(meal)
  end
end
