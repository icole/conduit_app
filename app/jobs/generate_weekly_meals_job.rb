class GenerateWeeklyMealsJob < ApplicationJob
  queue_as :default

  def perform(schedule_id: nil, weeks_ahead: 4)
    schedules = schedule_id ? MealSchedule.where(id: schedule_id) : MealSchedule.active
    created_count = 0

    schedules.find_each do |schedule|
      weeks_ahead.times do |week_offset|
        meal_date = schedule.next_occurrence(Date.current + week_offset.weeks)
        meal_datetime = schedule.start_time_on(meal_date)

        # Skip if meal already exists for this date
        next if schedule.meals.exists?(
          scheduled_at: meal_datetime.beginning_of_day..meal_datetime.end_of_day
        )

        schedule.generate_meal_for_date(meal_date)
        created_count += 1
      end
    end

    Rails.logger.info("GenerateWeeklyMealsJob: Created #{created_count} meals")
    created_count
  end
end
