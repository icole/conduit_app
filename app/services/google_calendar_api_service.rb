# frozen_string_literal: true

require "google/apis/calendar_v3"
require "googleauth"

# Service responsible for accessing Google Calendar API and returning events
class GoogleCalendarApiService
  attr_reader :calendar_service

  def initialize(auth_credentials)
    @calendar_service = Google::Apis::CalendarV3::CalendarService.new
    @calendar_service.client_options.application_name = "Community Hub"
    @calendar_service.authorization = auth_credentials
  end

  # Create from OAuth2 token (typically from user session)
  def self.from_oauth_token(access_token)
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"],
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY,
      access_token: access_token
    )
    new(credentials)
  end

  # Create from service account key file
  def self.from_service_account(key_file_path)
    return nil unless File.exist?(key_file_path)

    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(key_file_path),
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY
    )
    new(credentials)
  end

  # Get events from calendar within time range
  def get_events(calendar_id: "info@crowwoods.com", time_min: Time.now, time_max: nil, max_results: 100, search_query: nil)
    time_max ||= time_min + 90.days

    # Build request parameters
    params = {
      calendar_id: calendar_id,
      single_events: true,
      order_by: "startTime",
      max_results: max_results,
      time_min: time_min.iso8601,
      time_max: time_max.iso8601
    }

    # Add optional search query if provided
    params[:q] = search_query if search_query.present?

    # Execute API request
    begin
      events = calendar_service.list_events(params[:calendar_id],
                                           max_results: params[:max_results],
                                           single_events: params[:single_events],
                                           order_by: params[:order_by],
                                           q: params[:q],
                                           time_min: params[:time_min],
                                           time_max: params[:time_max])
      format_events(events.items)
    rescue Google::Apis::ClientError => e
      Rails.logger.error("Google Calendar API Client Error: #{e.message}")
      { error: e.message, status: :client_error, events: [] }
    rescue Google::Apis::ServerError => e
      Rails.logger.error("Google Calendar API Server Error: #{e.message}")
      { error: e.message, status: :server_error, events: [] }
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error("Google Calendar API Authorization Error: #{e.message}")
      { error: e.message, status: :auth_error, events: [] }
    end
  end

  # Get a single event by ID
  def get_event(calendar_id, event_id)
    begin
      event = calendar_service.get_event(calendar_id, event_id)
      format_event(event)
    rescue Google::Apis::ClientError => e
      Rails.logger.error("Google Calendar API Client Error: #{e.message}")
      { error: e.message, status: :client_error }
    rescue Google::Apis::ServerError => e
      Rails.logger.error("Google Calendar API Server Error: #{e.message}")
      { error: e.message, status: :server_error }
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error("Google Calendar API Authorization Error: #{e.message}")
      { error: e.message, status: :auth_error }
    end
  end

  # Get list of available calendars (basic info)
  def get_calendars
    begin
      calendar_list = calendar_service.list_calendar_lists
      calendar_list.items.map do |calendar|
        {
          id: calendar.id,
          summary: calendar.summary,
          description: calendar.description,
          primary: calendar.primary || false,
          access_role: calendar.access_role
        }
      end
    rescue Google::Apis::ClientError, Google::Apis::ServerError, Google::Apis::AuthorizationError => e
      Rails.logger.error("Google Calendar API Error: #{e.message}")
      { error: e.message, status: e.class.name.demodulize.underscore }
    end
  end

  # Get comprehensive list of all available calendars with detailed information
  def list_available_calendars
    begin
      # Get the raw calendar list from the API
      calendar_list = calendar_service.list_calendar_lists(min_access_role: "reader")

      # Process the results into a more useful format
      result = {
        calendars: [],
        primary_calendar: nil,
        status: :success
      }

      calendar_list.items.each do |calendar|
        calendar_details = {
          id: calendar.id,
          summary: calendar.summary,
          description: calendar.description,
          location: calendar.location,
          time_zone: calendar.time_zone,
          color_id: calendar.color_id,
          background_color: calendar.background_color,
          foreground_color: calendar.foreground_color,
          primary: calendar.primary || false,
          deleted: calendar.deleted || false,
          access_role: calendar.access_role,
          selected: calendar.selected || false,
          hidden: calendar.hidden || false,
          can_edit: [ "owner", "writer" ].include?(calendar.access_role),
          can_share: calendar.access_role == "owner",
          can_read: true
        }

        # Save reference to primary calendar
        result[:primary_calendar] = calendar_details if calendar.primary

        # Add to the list of calendars
        result[:calendars] << calendar_details
      end

      # Get event counts for each calendar if needed
      # This is commented out as it would require multiple API calls
      # result[:calendars] = add_event_counts(result[:calendars])

      # Sort by primary first, then by name
      result[:calendars].sort_by! { |c| [ c[:primary] ? 0 : 1, c[:summary].downcase ] }

      result
    rescue Google::Apis::ClientError, Google::Apis::ServerError, Google::Apis::AuthorizationError => e
      error_message = "Google Calendar API Error: #{e.message}"
      Rails.logger.error(error_message)
      {
        error: error_message,
        status: e.class.name.demodulize.underscore,
        calendars: []
      }
    end
  end

  # Get events for a specific date range (e.g., for a month view)
  def get_month_events(calendar_id: "primary", date: Date.today)
    start_date = date.beginning_of_month.beginning_of_week
    end_date = date.end_of_month.end_of_week
    get_events(calendar_id: calendar_id, time_min: start_date.to_time, time_max: end_date.to_time, max_results: 2500)
  end

  private

  # Format a collection of events for easier consumption
  def format_events(events)
    formatted_events = events.map { |event| format_event(event) }
    { events: formatted_events, count: formatted_events.length, status: :success }
  end

  # Format a single event for easier consumption
  def format_event(event)
    return nil if event.nil?

    # Extract start and end times, handling both date and datetime formats
    start_time = event.start.date_time || Time.zone.parse(event.start.date.to_s)
    end_time = event.end.date_time || Time.zone.parse(event.end.date.to_s)
    all_day = event.start.date.present?

    {
      id: event.id,
      summary: event.summary,
      description: event.description,
      location: event.location,
      start_time: start_time,
      end_time: end_time,
      all_day: all_day,
      creator: event.creator&.email,
      creator_name: event.creator&.display_name,
      organizer: event.organizer&.email,
      organizer_name: event.organizer&.display_name,
      html_link: event.html_link,
      status: event.status,
      created: event.created,
      updated: event.updated,
      color_id: event.color_id,
      calendar_id: event.organizer&.email || "primary"
    }
  end

  # Add event counts for each calendar (optional helper method)
  def add_event_counts(calendars, days_to_check = 30)
    time_min = Time.now
    time_max = time_min + days_to_check.days

    calendars.map do |calendar|
      begin
        # Only make API call if we have read access
        if calendar[:can_read]
          events = calendar_service.list_events(
            calendar[:id],
            max_results: 250,
            single_events: true,
            time_min: time_min.iso8601,
            time_max: time_max.iso8601
          )
          calendar[:upcoming_event_count] = events.items.count
        end
      rescue => e
        Rails.logger.error("Error getting event count for calendar #{calendar[:id]}: #{e.message}")
        calendar[:upcoming_event_count] = 0
      end
      calendar
    end
  end
end
