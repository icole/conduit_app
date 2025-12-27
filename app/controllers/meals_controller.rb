class MealsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_meal, only: [ :show, :edit, :update, :destroy,
                                   :volunteer_cook, :withdraw_cook,
                                   :rsvp, :cancel_rsvp, :close_rsvps,
                                   :complete, :cancel, :cook, :show_rsvp,
                                   :update_menu ]

  helper_method :meals_back_path

  def index
    session[:meals_view] = "list"
    @current_view = params[:view] || "upcoming"
    @needs_cooks_count = Meal.needs_cooks.length

    case @current_view
    when "upcoming"
      @meals = Meal.upcoming.includes(:meal_cooks, :cooks, :meal_rsvps)
    when "past"
      @meals = Meal.past.includes(:meal_cooks, :cooks).limit(20)
    when "needs_cooks"
      @meals = Meal.needs_cooks.includes(:meal_schedule)
    else
      @meals = Meal.upcoming.includes(:meal_cooks, :cooks, :meal_rsvps)
    end
  end

  def show
    @comments = @meal.comments.includes(:user, :likes).order(created_at: :asc)
    @comment = Comment.new
    @my_rsvp = @meal.rsvp_for(current_user)
    @my_cook_signup = @meal.cook_for(current_user)
    @attending_rsvps = @meal.meal_rsvps.attending.includes(:user)
    @maybe_rsvps = @meal.meal_rsvps.maybe.includes(:user)
    @declined_rsvps = @meal.meal_rsvps.declined.includes(:user)
  end

  def cook
    @my_cook_signup = @meal.cook_for(current_user)
  end

  def show_rsvp
    @my_rsvp = @meal.rsvp_for(current_user)
    render :rsvp
  end

  def new
    @meal = Meal.new(
      scheduled_at: Time.current.tomorrow.change(hour: 18),
      rsvp_deadline: Time.current.tomorrow.change(hour: 18) - 24.hours
    )
  end

  def create
    @meal = Meal.new(meal_params)

    if @meal.save
      redirect_to @meal, notice: "Meal created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @meal.update(meal_params)
      redirect_to @meal, notice: "Meal updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @meal.discard
    redirect_to meals_path, notice: "Meal removed."
  end

  def calendar
    session[:meals_view] = "calendar"
    session[:meals_calendar_date] = params[:date]
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @start_of_month = @date.beginning_of_month
    @end_of_month = @date.end_of_month

    # Calculate the calendar grid dates (may include days from prev/next month)
    @calendar_start = @start_of_month.beginning_of_week(:monday)
    @calendar_end = @end_of_month.end_of_week(:monday)

    @meals = Meal.where(scheduled_at: @calendar_start.beginning_of_day..@calendar_end.end_of_day)
                 .includes(:meal_cooks, :cooks, :meal_rsvps)
                 .order(:scheduled_at)
    @meals_by_date = @meals.group_by(&:scheduled_date)
  end

  def my_meals
    @cooking = current_user.cooking_meals.upcoming.includes(:meal_cooks, :meal_schedule)
    @attending = current_user.rsvped_meals.upcoming.includes(:meal_rsvps, :meal_cooks)
  end

  # POST /meals/:id/volunteer_cook
  def volunteer_cook
    role = params[:role].presence || "helper"
    @meal_cook = @meal.meal_cooks.build(
      user: current_user,
      role: role,
      notes: params[:notes]
    )

    if @meal_cook.save
      redirect_to @meal, notice: "Thank you for volunteering to cook!"
    else
      redirect_to @meal, alert: @meal_cook.errors.full_messages.join(", ")
    end
  end

  # DELETE /meals/:id/withdraw_cook
  def withdraw_cook
    @meal_cook = @meal.meal_cooks.find_by(user: current_user)
    if @meal_cook&.destroy
      redirect_to @meal, notice: "You've withdrawn from cooking this meal."
    else
      redirect_to @meal, alert: "You weren't signed up to cook this meal."
    end
  end

  # POST /meals/:id/rsvp
  def rsvp
    @rsvp = @meal.meal_rsvps.find_or_initialize_by(user: current_user)
    @rsvp.assign_attributes(rsvp_params)

    if @rsvp.save
      redirect_to @meal, notice: "Your RSVP has been recorded!"
    else
      redirect_to @meal, alert: @rsvp.errors.full_messages.join(", ")
    end
  end

  # DELETE /meals/:id/cancel_rsvp
  def cancel_rsvp
    @rsvp = @meal.meal_rsvps.find_by(user: current_user)
    if @rsvp&.destroy
      redirect_to @meal, notice: "Your RSVP has been cancelled."
    else
      redirect_to @meal, alert: "You didn't have an RSVP for this meal."
    end
  end

  # POST /meals/:id/close_rsvps
  def close_rsvps
    @meal.close_rsvps!
    redirect_to @meal, notice: "RSVPs have been closed."
  end

  # POST /meals/:id/complete
  def complete
    @meal.complete!
    redirect_to @meal, notice: "Meal marked as completed."
  end

  # POST /meals/:id/cancel
  def cancel
    @meal.cancel!
    redirect_to @meal, notice: "Meal has been cancelled."
  end

  # PATCH /meals/:id/update_menu
  def update_menu
    unless @meal.user_is_cook?(current_user)
      redirect_to @meal, alert: "Only cooks can update the menu."
      return
    end

    menu_value = params.dig(:meal, :menu)
    if @meal.update(menu: menu_value)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @meal, notice: "Menu updated!" }
      end
    else
      redirect_to @meal, alert: "Could not update menu."
    end
  end

  private

  def set_meal
    @meal = Meal.find(params[:id])
  end

  def meal_params
    params.require(:meal).permit(
      :title, :description, :scheduled_at, :rsvp_deadline,
      :location, :max_attendees, :meal_schedule_id, :cook_notes, :menu
    )
  end

  def rsvp_params
    params.require(:meal_rsvp).permit(:status, :guests_count, :notes)
  end

  def meals_back_path
    if session[:meals_view] == "calendar"
      calendar_meals_path(date: session[:meals_calendar_date])
    else
      meals_path
    end
  end
end
