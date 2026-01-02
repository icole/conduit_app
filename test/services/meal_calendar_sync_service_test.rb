# frozen_string_literal: true

require "test_helper"

class MealCalendarSyncServiceTest < ActiveSupport::TestCase
  setup do
    @community = communities(:crow_woods)
    ActsAsTenant.current_tenant = @community
    # Use needs_cook meal which has no cooks by default
    @meal = meals(:needs_cook)
    @service = MealCalendarSyncService.new(@meal)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "event_title shows cook names when cooks are assigned" do
    # Add cooks to the meal
    head_cook = users(:one)
    helper = users(:two)
    @meal.meal_cooks.create!(user: head_cook, role: "head_cook")
    @meal.meal_cooks.create!(user: helper, role: "helper")

    title = @service.send(:event_title)

    # Should include cook names, not meal title
    assert_includes title, head_cook.name
    assert_includes title, helper.name
    assert_not_includes title, @meal.title
  end

  test "event_title shows single cook name with possessive" do
    cook = users(:one)
    @meal.meal_cooks.create!(user: cook, role: "head_cook")

    title = @service.send(:event_title)

    assert_equal "#{cook.name}'s Meal", title
  end

  test "event_title shows two cooks joined with ampersand" do
    cook1 = users(:one)
    cook2 = users(:two)
    @meal.meal_cooks.create!(user: cook1, role: "head_cook")
    @meal.meal_cooks.create!(user: cook2, role: "helper")

    title = @service.send(:event_title)

    assert_equal "#{cook1.name} & #{cook2.name}'s Meal", title
  end

  test "event_title falls back to Community Meal when no cooks" do
    # needs_cook meal has no cooks
    title = @service.send(:event_title)

    assert_equal "Community Meal", title
  end

  test "event_description includes menu when present" do
    @meal.update!(menu: "Tacos, rice, and beans")

    description = @service.send(:event_description)

    assert_includes description, "Menu:"
    assert_includes description, "Tacos, rice, and beans"
  end

  test "event_description does not include menu section when blank" do
    @meal.update!(menu: nil)

    description = @service.send(:event_description)

    assert_not_includes description, "Menu:"
  end
end
