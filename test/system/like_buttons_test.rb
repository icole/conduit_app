require "application_system_test_case"

class LikeButtonsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @chore = Chore.create!(
      name: "Water the orchard",
      description: "Weekly watering rota",
      frequency: "weekly",
      proposed_by: @user,
      status: "active"
    )
    @chore_comment = @chore.comments.create!(content: "I can take Tuesdays", user: users(:two))

    sign_in_user
  end

  test "can like and unlike a chore" do
    visit chore_path(@chore)

    find("[data-testid='like-topic-button-#{@chore.id}']").click
    assert find("[data-testid='unlike-topic-button-#{@chore.id}']").visible?

    find("[data-testid='unlike-topic-button-#{@chore.id}']").click
    assert find("[data-testid='like-topic-button-#{@chore.id}']").visible?
  end

  test "can like and unlike a chore comment" do
    visit chore_path(@chore)

    find("[data-testid='like-comment-button-#{@chore_comment.id}']").click
    assert find("[data-testid='unlike-comment-button-#{@chore_comment.id}']").visible?

    find("[data-testid='unlike-comment-button-#{@chore_comment.id}']").click
    assert find("[data-testid='like-comment-button-#{@chore_comment.id}']").visible?
  end
end
