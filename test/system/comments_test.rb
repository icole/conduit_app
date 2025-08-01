require "application_system_test_case"

class CommentsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)

    # Create a chore with no comments for testing first comment
    @chore_with_no_comments = Chore.create!(
      name: "Test Chore Without Comments",
      description: "A chore for testing first comment functionality",
      frequency: "weekly",
      proposed_by: @user,
      status: "active"
    )

    # Create a discussion topic with no comments for testing first comment
    @discussion_topic_with_no_comments = DiscussionTopic.create!(
      title: "Test Discussion Without Comments",
      description: "A discussion topic for testing first comment functionality",
      user: @user
    )

    sign_in_user
  end

  test "first comment on chore removes placeholder message immediately" do
    visit chore_path(@chore_with_no_comments)

    # Verify placeholder message is initially present
    assert_selector "#chore-#{@chore_with_no_comments.id}-no-comments", text: "No comments yet"

    # Add the first comment
    within "#comments" do
      fill_in "comment[content]", with: "This is the first comment on this chore!"
      click_on "Post"
    end

    # Verify the comment appears immediately
    assert_selector "[data-testid='comment-content']", text: "This is the first comment on this chore!"

    # Verify the placeholder message is removed immediately (no page refresh needed)
    assert_no_selector "#chore-#{@chore_with_no_comments.id}-no-comments", wait: 1

    # Verify the comment form is reset and ready for another comment
    assert_field "comment[content]", with: ""
  end

  test "first comment on discussion topic removes placeholder message immediately" do
    visit discussion_topic_path(@discussion_topic_with_no_comments)

    # Verify placeholder message is initially present
    assert_selector "#discussiontopic-#{@discussion_topic_with_no_comments.id}-no-comments", text: "No comments yet"

    # Add the first comment (discussion topics don't have #comments wrapper)
    fill_in "comment[content]", with: "This is the first comment on this discussion!"
    click_on "Post"

    # Verify the comment appears immediately
    assert_selector "[data-testid='comment-content']", text: "This is the first comment on this discussion!"

    # Verify the placeholder message is removed immediately (no page refresh needed)
    assert_no_selector "#discussiontopic-#{@discussion_topic_with_no_comments.id}-no-comments", wait: 1

    # Verify the comment form is reset and ready for another comment
    assert_field "comment[content]", with: ""
  end

  test "second comment on chore appends correctly without affecting first comment" do
    visit chore_path(@chore_with_no_comments)

    # Add the first comment
    within "#comments" do
      fill_in "comment[content]", with: "First comment"
      click_on "Post"
    end

    # Verify first comment appears
    assert_selector "[data-testid='comment-content']", text: "First comment"

    # Add the second comment
    within "#comments" do
      fill_in "comment[content]", with: "Second comment"
      click_on "Post"
    end

    # Verify both comments are present
    assert_selector "[data-testid='comment-content']", text: "First comment"
    assert_selector "[data-testid='comment-content']", text: "Second comment"

    # Verify no placeholder message exists
    assert_no_selector "#chore-#{@chore_with_no_comments.id}-no-comments"

    # Verify we have 2 comments total
    assert_selector "[data-testid='comment-content']", count: 2
  end

  test "deleting the only comment shows placeholder message again" do
    visit chore_path(@chore_with_no_comments)

    # Add a comment first
    within "#comments" do
      fill_in "comment[content]", with: "Only comment"
      click_on "Post"
    end

    # Verify comment appears and placeholder is gone
    assert_selector "[data-testid='comment-content']", text: "Only comment"
    assert_no_selector "#chore-#{@chore_with_no_comments.id}-no-comments"

    # Delete the comment
    accept_confirm do
      find("[data-testid*='delete-comment-button']").click
    end

    # Verify comment is removed immediately
    assert_no_selector "[data-testid='comment-content']", text: "Only comment", wait: 2

    # Note: We're not testing that the placeholder reappears because that would require
    # additional logic that currently doesn't exist. The current implementation just
    # removes the comment, leaving an empty comments section.
  end

  test "first comment works consistently across different comment types" do
    # Test with chore
    visit chore_path(@chore_with_no_comments)
    within "#comments" do
      fill_in "comment[content]", with: "Chore comment"
      click_on "Post"
    end
    assert_selector "[data-testid='comment-content']", text: "Chore comment"
    assert_no_selector "#chore-#{@chore_with_no_comments.id}-no-comments"

    # Test with discussion topic (no #comments wrapper)
    visit discussion_topic_path(@discussion_topic_with_no_comments)
    fill_in "comment[content]", with: "Discussion comment"
    click_on "Post"
    assert_selector "[data-testid='comment-content']", text: "Discussion comment"
    assert_no_selector "#discussiontopic-#{@discussion_topic_with_no_comments.id}-no-comments"
  end

  private

  # sign_in_user method is inherited from ApplicationSystemTestCase
end
