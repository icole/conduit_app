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

  test "event_title shows first names of cooks in parentheses" do
    # Add cooks to the meal
    head_cook = users(:one)  # Jane Smith
    helper = users(:two)     # Mike Davis
    @meal.meal_cooks.create!(user: head_cook, role: "head_cook")
    @meal.meal_cooks.create!(user: helper, role: "helper")

    title = @service.send(:event_title)

    assert_equal "Community Meal (Jane & Mike)", title
  end

  test "event_title shows single cook first name" do
    cook = users(:one)  # Jane Smith
    @meal.meal_cooks.create!(user: cook, role: "head_cook")

    title = @service.send(:event_title)

    assert_equal "Community Meal (Jane)", title
  end

  test "event_title shows three cooks with commas and ampersand" do
    cook1 = users(:one)    # Jane Smith
    cook2 = users(:two)    # Mike Davis
    cook3 = users(:three)  # Alice Johnson
    @meal.meal_cooks.create!(user: cook1, role: "head_cook")
    @meal.meal_cooks.create!(user: cook2, role: "helper")
    @meal.meal_cooks.create!(user: cook3, role: "helper")

    title = @service.send(:event_title)

    assert_equal "Community Meal (Jane, Mike & Alice)", title
  end

  test "event_title is just Community Meal when no cooks" do
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

  # CON-34: the sync used ENV["GOOGLE_CALENDAR_ID"], Crow Woods' calendar, for
  # every community, so the demo community's meals appeared there
  test "a meal goes to its own community's calendar" do
    crow_woods = communities(:crow_woods)
    crow_woods.update!(settings: (crow_woods.settings || {}).merge("google_calendar_id" => "crow-woods@group.calendar.google.com"))
    meal = ActsAsTenant.with_tenant(crow_woods) { Meal.create!(title: "Dinner", scheduled_at: 3.days.from_now, rsvp_deadline: 2.days.from_now) }

    assert_equal "crow-woods@group.calendar.google.com", MealCalendarSyncService.new(meal).send(:calendar_id)
  end

  test "a community without its own calendar isn't synced anywhere" do
    other = communities(:other_community)
    meal = ActsAsTenant.with_tenant(other) { Meal.create!(title: "Dinner", scheduled_at: 3.days.from_now, rsvp_deadline: 2.days.from_now) }

    ENV["GOOGLE_CALENDAR_ID"] = "crow-woods@group.calendar.google.com"
    assert_equal({ status: :skipped, reason: "No calendar configured" }, MealCalendarSyncService.new(meal).sync)
  ensure
    ENV.delete("GOOGLE_CALENDAR_ID")
  end
end
