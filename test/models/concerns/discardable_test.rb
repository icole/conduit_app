# frozen_string_literal: true

require "test_helper"

class DiscardableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @meal = meals(:upcoming_meal)
    Current.user = @user
  end

  teardown do
    Current.user = nil
  end

  test "discard sets discarded_at timestamp" do
    assert_nil @meal.discarded_at
    @meal.discard
    assert_not_nil @meal.discarded_at
  end

  test "discard sets deleted_by to Current.user" do
    @meal.discard
    assert_equal @user, @meal.deleted_by
  end

  test "discard without Current.user leaves deleted_by nil" do
    Current.user = nil
    @meal.discard
    assert_nil @meal.deleted_by
  end

  test "soft deleted records are excluded from default scope" do
    meal_id = @meal.id
    @meal.discard
    refute Meal.exists?(meal_id)
    assert Meal.with_discarded.exists?(meal_id)
  end

  test "soft_delete is aliased to discard" do
    @meal.soft_delete
    assert @meal.discarded?
  end

  test "soft_deleted? is aliased to discarded?" do
    refute @meal.soft_deleted?
    @meal.discard
    assert @meal.soft_deleted?
  end

  test "restore is aliased to undiscard" do
    @meal.discard
    assert @meal.discarded?
    @meal.restore
    refute @meal.discarded?
  end

  test "with_discarded scope includes soft deleted records" do
    meal_id = @meal.id
    @meal.discard
    refute Meal.exists?(meal_id)
    assert Meal.with_discarded.exists?(meal_id)
  end

  test "only_discarded scope returns only soft deleted records" do
    other_meal = meals(:needs_cook)
    @meal.discard

    discarded_ids = Meal.only_discarded.pluck(:id)
    assert_includes discarded_ids, @meal.id
    refute_includes discarded_ids, other_meal.id
  end

  test "created_by is set on create for models with user association" do
    new_task = @user.tasks.create!(title: "Test task", status: "backlog", workstream: workstreams(:general))
    assert_equal @user, new_task.created_by
  end

  test "cascade_discard soft deletes associated comments" do
    comment = @meal.comments.create!(content: "Test comment", user: @user)
    refute comment.discarded?

    @meal.discard

    comment.reload
    assert comment.discarded?
  end

  test "undiscard restores cascaded comments" do
    comment = @meal.comments.create!(content: "Test comment", user: @user)
    @meal.discard
    assert comment.reload.discarded?

    @meal.undiscard

    comment.reload
    refute comment.discarded?
  end
end
