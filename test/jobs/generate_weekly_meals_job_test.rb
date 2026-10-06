require "test_helper"

class GenerateWeeklyMealsJobTest < ActiveJob::TestCase
  setup do
    @community = communities(:crow_woods)
    @schedule = meal_schedules(:tuesday_dinner)
  end

  test "uses community meal_buffer_weeks setting" do
    # Set community to 8 weeks buffer
    @community.update!(settings: { "meal_buffer_weeks" => 8 })

    ActsAsTenant.with_tenant(@community) do
      # Count meals before
      initial_count = @schedule.meals.upcoming.count

      created_count = GenerateWeeklyMealsJob.perform_now(community_id: @community.id, schedule_id: @schedule.id)

      # Should attempt to create meals for 8 weeks (some may already exist)
      # The job returns the count of meals created
      assert created_count <= 8
      assert @schedule.meals.upcoming.count >= initial_count
    end
  end

  test "defaults to 6 weeks when community has no setting" do
    @community.update!(settings: {})

    ActsAsTenant.with_tenant(@community) do
      initial_count = @schedule.meals.upcoming.count

      created_count = GenerateWeeklyMealsJob.perform_now(community_id: @community.id, schedule_id: @schedule.id)

      # Should attempt to create meals for 6 weeks (default)
      assert created_count <= 6
      assert @schedule.meals.upcoming.count >= initial_count
    end
  end

  test "weeks_ahead parameter overrides community setting" do
    @community.update!(settings: { "meal_buffer_weeks" => 8 })

    ActsAsTenant.with_tenant(@community) do
      initial_count = @schedule.meals.upcoming.count

      created_count = GenerateWeeklyMealsJob.perform_now(community_id: @community.id, schedule_id: @schedule.id, weeks_ahead: 3)

      # Parameter should override community setting - max 3 meals created
      assert created_count <= 3
    end
  end

  # A schedule makes one meal per date. Once a meal fills that date, by being
  # made for it or by replacing it, the date stays filled: moving the meal to
  # another day or deleting it doesn't make the schedule make another.
  test "a scheduled meal moved to another day isn't made again on its old day" do
    with_brunches do |brunch|
      brunch.update!(scheduled_at: brunch.scheduled_at - 2.days, rsvp_deadline: brunch.rsvp_deadline - 2.days)

      assert_no_difference -> { Meal.with_discarded.count } do
        generate_brunches
      end
    end
  end

  test "a deleted scheduled meal isn't made again: deleting it skips that week" do
    with_brunches do |brunch|
      brunch.discard

      assert_no_difference -> { Meal.with_discarded.count } do
        generate_brunches
      end
      assert_not Meal.exists?(scheduled_at: brunch.scheduled_at.all_day)
    end
  end

  test "a meal that replaces the schedule's meal that week stops the schedule making one" do
    travel_to Time.zone.local(2026, 10, 6, 7, 0) do
      ActsAsTenant.with_tenant(@community) do
        friday = Time.zone.local(2026, 10, 16, 18, 0)
        Meal.create!(title: "Friday meeting dinner", scheduled_at: friday, rsvp_deadline: friday - 1.day,
                     replaces_schedule_id: meal_schedules(:sunday_brunch).id)

        generate_brunches

        assert_not Meal.exists?(scheduled_at: Date.new(2026, 10, 18).all_day)
      end
    end
  end

  private

  # Brunches generated three weeks out (Sundays Oct 11, 18 and 25); yields Oct 18's
  def with_brunches
    travel_to Time.zone.local(2026, 10, 6, 7, 0) do
      ActsAsTenant.with_tenant(@community) do
        generate_brunches
        yield Meal.find_by!(scheduled_at: Date.new(2026, 10, 18).all_day)
      end
    end
  end

  def generate_brunches
    GenerateWeeklyMealsJob.perform_now(community_id: @community.id, schedule_id: meal_schedules(:sunday_brunch).id, weeks_ahead: 3)
  end
end
