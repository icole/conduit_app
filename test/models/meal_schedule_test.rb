require "test_helper"

class MealScheduleTest < ActiveSupport::TestCase
  setup do
    @schedule = meal_schedules(:tuesday_dinner)
  end

  test "destroy succeeds when associated meals have been discarded" do
    # Create a meal associated with this schedule
    meal = @schedule.generate_meal_for_date(@schedule.next_occurrence)

    # Soft-delete the meal (simulates production scenario)
    meal.discard

    # Destroying the schedule should not raise FK violation
    assert_nothing_raised do
      @schedule.destroy!
    end

    # Verify the meal was hard-deleted
    assert_not Meal.unscoped.exists?(meal.id)
  end

  test "destroy succeeds when mix of active and discarded meals exist" do
    meal1 = @schedule.generate_meal_for_date(Date.current + 7.days)
    meal2 = @schedule.generate_meal_for_date(Date.current + 14.days)

    # Discard one, leave one active
    meal1.discard

    assert_nothing_raised do
      @schedule.destroy!
    end

    assert_not Meal.unscoped.exists?(meal1.id)
    assert_not Meal.unscoped.exists?(meal2.id)
  end
end
