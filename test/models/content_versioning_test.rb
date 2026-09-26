# frozen_string_literal: true

require "test_helper"

# Provenance for the content people create together: who made it, who changed
# it, and what it said before. Document bodies are deliberately excluded - see
# the document tests below.
class ContentVersioningTest < ActiveSupport::TestCase
  def versions_for(record)
    PaperTrail::Version.where(item_type: record.class.name, item_id: record.id)
  end

  # --- meals ---

  test "creating a meal is recorded" do
    meal = Meal.new(title: "Soup night", scheduled_at: 1.week.from_now, rsvp_deadline: 6.days.from_now)

    assert_difference "PaperTrail::Version.where(item_type: 'Meal').count", 1 do
      meal.save!
    end
    assert_equal "create", meal.versions.last.event
  end

  test "changing a meal keeps what it said before" do
    meal = meals(:upcoming_meal)
    was = meal.title
    meal.update!(title: "Renamed meal")

    assert_equal was, meal.versions.last.reify.title
  end

  test "cancelling a meal is recorded" do
    meal = meals(:upcoming_meal)

    assert_difference "versions_for(meal).count", 1 do
      meal.update!(status: "cancelled")
    end
  end

  # --- decisions ---

  test "creating and editing a decision is recorded" do
    decision = Decision.new(title: "Adopt the new quiet hours")

    assert_difference "PaperTrail::Version.where(item_type: 'Decision').count", 1 do
      decision.save!
    end

    decision.update!(description: "Agreed at the September meeting")
    assert_equal "update", decision.versions.last.event
  end

  # --- comments ---

  test "creating a comment is recorded" do
    comment = Comment.new(content: "Count me in", user: users(:one), commentable: meals(:upcoming_meal))

    assert_difference "PaperTrail::Version.where(item_type: 'Comment').count", 1 do
      comment.save!
    end
  end

  test "editing and soft deleting a comment is recorded" do
    comment = comments(:one)
    was = comment.content
    comment.update!(content: "Edited")
    assert_equal was, comment.versions.last.reify.content

    assert_difference "versions_for(comment).count", 1 do
      comment.discard
    end
  end

  # --- documents: metadata yes, body no ---

  test "changing a document's metadata is recorded" do
    document = documents(:one)
    was = document.title
    document.update!(title: "Renamed document")

    assert_equal "update", document.versions.last.event
    assert_equal was, document.versions.last.reify.title
  end

  test "saving a document's body does not create a version" do
    document = documents(:native_doc)

    # The React editor autosaves content; production has bodies over 600 KB, so
    # versioning them would copy the whole document on every keystroke batch.
    assert_no_difference "versions_for(document).count" do
      document.update!(content: "a much longer body " * 100)
    end
  end

  test "a document version does not carry the body" do
    document = documents(:native_doc)
    document.update!(content: "secret body text")
    document.update!(title: "Title change after a body change")

    assert_not_includes document.versions.last.object.to_s, "secret body text"
  end
end
