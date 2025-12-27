# frozen_string_literal: true

# Service to sync meals with Google Calendar
class MealCalendarSyncService
  MEAL_DURATION_HOURS = 2

  def initialize(meal)
    @meal = meal
  end

  def sync
    return { status: :skipped, reason: "No calendar configured" } unless calendar_id.present?

    if @meal.google_event_id.present?
      update_event
    else
      create_event
    end
  end

  def delete
    return { status: :skipped, reason: "No event to delete" } unless @meal.google_event_id.present?
    return { status: :skipped, reason: "No calendar configured" } unless calendar_id.present?

    result = calendar_service.delete_event(
      calendar_id: calendar_id,
      event_id: @meal.google_event_id
    )

    if result[:status] == :success
      @meal.update_column(:google_event_id, nil)
    end

    result
  end

  private

  def create_event
    result = calendar_service.create_event(
      calendar_id: calendar_id,
      title: event_title,
      start_time: @meal.scheduled_at,
      end_time: @meal.scheduled_at + MEAL_DURATION_HOURS.hours,
      description: event_description,
      location: event_location
    )

    if result[:status] == :success
      @meal.update_column(:google_event_id, result[:event_id])
    end

    result
  end

  def update_event
    result = calendar_service.update_event(
      calendar_id: calendar_id,
      event_id: @meal.google_event_id,
      title: event_title,
      start_time: @meal.scheduled_at,
      end_time: @meal.scheduled_at + MEAL_DURATION_HOURS.hours,
      description: event_description,
      location: event_location
    )

    # If event was deleted from Google Calendar, create a new one
    if result[:status] == :client_error && result[:error]&.include?("Not Found")
      @meal.update_column(:google_event_id, nil)
      create_event
    else
      result
    end
  end

  def event_title
    "Community Meal: #{@meal.title}"
  end

  def event_description
    parts = []

    if @meal.description.present?
      parts << @meal.description
    end

    if @meal.cooks.any?
      cook_names = @meal.cooks.map(&:name).join(", ")
      parts << "Cooks: #{cook_names}"
    end

    if @meal.rsvps_open?
      parts << "RSVPs open until #{@meal.rsvp_deadline.strftime('%B %d at %l:%M %p')}"
    end

    parts.join("\n\n")
  end

  def event_location
    @meal.community&.name.presence || "Common House"
  end

  def calendar_id
    ENV["GOOGLE_CALENDAR_ID"]
  end

  def calendar_service
    @calendar_service ||= GoogleCalendarApiService.from_service_account_with_acl_scope
  end
end
