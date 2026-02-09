class MealSchedulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_meal_schedule, only: [ :edit, :update, :destroy, :toggle_active, :generate_meals ]

  def index
    @schedules = MealSchedule.includes(:created_by).ordered
    @active_schedules = @schedules.active
    @inactive_schedules = @schedules.inactive
    @community = ActsAsTenant.current_tenant
  end

  def update_settings
    community = ActsAsTenant.current_tenant
    buffer_weeks = params[:meal_buffer_weeks].to_i.clamp(1, 12)
    community.meal_buffer_weeks = buffer_weeks
    community.save!

    redirect_to meal_schedules_path, notice: "Meal buffer updated to #{buffer_weeks} weeks."
  end

  def new
    @schedule = MealSchedule.new(
      rsvp_deadline_hours: 24,
      max_cooks: 2,
      active: true
    )
  end

  def create
    @schedule = MealSchedule.new(schedule_params)
    @schedule.created_by = current_user

    if @schedule.save
      redirect_to meal_schedules_path, notice: "Meal schedule created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @schedule.update(schedule_params)
      redirect_to meal_schedules_path, notice: "Schedule updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    meal_count = @schedule.meals.count
    schedule_name = @schedule.name
    @schedule.destroy

    if meal_count > 0
      redirect_to meal_schedules_path, notice: "Schedule '#{schedule_name}' and #{meal_count} associated #{'meal'.pluralize(meal_count)} deleted."
    else
      redirect_to meal_schedules_path, notice: "Schedule '#{schedule_name}' deleted."
    end
  end

  def toggle_active
    @schedule.toggle_active!
    status = @schedule.active? ? "activated" : "paused"
    redirect_to meal_schedules_path, notice: "Schedule #{status}."
  end

  def generate_meals
    weeks = (params[:weeks] || 4).to_i.clamp(1, 12)
    count = 0

    weeks.times do |week_offset|
      meal_date = @schedule.next_occurrence(Date.current + week_offset.weeks)
      meal_datetime = @schedule.start_time_on(meal_date)

      # Skip if meal already exists for this date
      next if @schedule.meals.exists?(
        scheduled_at: meal_datetime.beginning_of_day..meal_datetime.end_of_day
      )

      @schedule.generate_meal_for_date(meal_date)
      count += 1
    end

    redirect_to meal_schedules_path, notice: "Generated #{count} meals from this schedule."
  end

  private

  def set_meal_schedule
    @schedule = MealSchedule.find(params[:id])
  end

  def schedule_params
    params.require(:meal_schedule).permit(
      :name, :day_of_week, :start_time, :end_time,
      :location, :max_cooks, :rsvp_deadline_hours, :active
    )
  end
end
