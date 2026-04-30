class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @tasks = Task.where(assigned_to_user_id: current_user.id)
                 .where(status: "active")
    @task = Task.new

    @calendar_already_shared = begin
      calendar_id = current_community.google_calendar_id
      calendar_id.present? && CalendarShare.calendar_shared_with_user?(calendar_id, current_user)
    end

    @google_calendar_configured = begin
      defined?(CalendarCredentials) && CalendarCredentials.configured? && current_community.google_calendar_id.present?
    rescue
      false
    end

    @timeline_items = build_timeline
  end

  def documents_section
    @drive_files = []
    drive_service = GoogleDriveBrowseService.new(current_community)
    if drive_service.configured?
      result = drive_service.recent_files
      @drive_files = result[:files] || []
    end

    render partial: "dashboard/documents_section", layout: false
  end

  private

  def build_timeline
    items = []

    # Add upcoming meals
    meals = Meal.where(community: current_community)
                .upcoming
                .includes(:cooks, :meal_cooks, :meal_rsvps)
                .limit(10)

    meals.each do |meal|
      items << {
        type: :meal,
        start_time: meal.scheduled_at,
        meal: meal
      }
    end

    # Add calendar events (skip in test env since it hits Google API)
    if !Rails.env.test? && @google_calendar_configured
      begin
        # Collect google_event_ids from meals to filter out duplicates
        meal_google_event_ids = meals.filter_map(&:google_event_id).to_set

        service = GoogleCalendarApiService.from_service_account_with_acl_scope
        result = service.get_events(max_results: 10)
        if result[:events].present?
          result[:events].each do |event|
            # Skip calendar events that are synced meals (already in timeline)
            next if meal_google_event_ids.include?(event[:id])

            items << {
              type: :event,
              start_time: event[:start_time],
              event: event
            }
          end
        end
      rescue StandardError => e
        Rails.logger.error("Failed to load calendar events: #{e.message}")
      end
    end

    # Sort by start time and limit to 10
    items.sort_by { |item| item[:start_time] }.first(10)
  end
end
