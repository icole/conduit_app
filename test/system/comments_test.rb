require "application_system_test_case"

class CommentsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    # A meal with no comments, for testing the first-comment placeholder
    @meal = meals(:upcoming_meal)
    @meal.comments.destroy_all

    sign_in_user
  end

  test "first comment on a meal removes placeholder message immediately" do
    visit meal_path(@meal)

    assert_selector "#meal-#{@meal.id}-no-comments", text: "No comments yet"

    fill_in "comment[content]", with: "This is the first comment on this meal!"
    click_on "Post"

    assert_selector "[data-testid='comment-content']", text: "This is the first comment on this meal!"
    assert_no_selector "#meal-#{@meal.id}-no-comments", wait: 1
    assert_field "comment[content]", with: ""
  end

  test "second comment appends without affecting the first" do
    visit meal_path(@meal)

    fill_in "comment[content]", with: "First comment"
    click_on "Post"
    assert_selector "[data-testid='comment-content']", text: "First comment"

    fill_in "comment[content]", with: "Second comment"
    click_on "Post"

    assert_selector "[data-testid='comment-content']", text: "First comment"
    assert_selector "[data-testid='comment-content']", text: "Second comment"
    assert_no_selector "#meal-#{@meal.id}-no-comments"
    assert_selector "[data-testid='comment-content']", count: 2
  end

  test "deleting a comment removes it immediately" do
    visit meal_path(@meal)

    fill_in "comment[content]", with: "Only comment"
    click_on "Post"
    assert_selector "[data-testid='comment-content']", text: "Only comment"

    accept_confirm do
      find("[data-testid*='delete-comment-button']").click
    end

    assert_no_selector "[data-testid='comment-content']", text: "Only comment", wait: 2
  end
end
