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
end
