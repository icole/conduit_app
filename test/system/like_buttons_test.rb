require "application_system_test_case"

class LikeButtonsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @meal = meals(:upcoming_meal)
    @meal_comment = @meal.comments.create!(content: "Count me in", user: users(:two))

    sign_in_user
  end

  test "can like and unlike a meal comment" do
    visit meal_path(@meal)

    find("[data-testid='like-comment-button-#{@meal_comment.id}']").click
    assert find("[data-testid='unlike-comment-button-#{@meal_comment.id}']").visible?

    find("[data-testid='unlike-comment-button-#{@meal_comment.id}']").click
    assert find("[data-testid='like-comment-button-#{@meal_comment.id}']").visible?
  end
end
