# frozen_string_literal: true

class CalendarEventsController < ApplicationController
  skip_before_action :authenticate_user! # Temporary for testing
  before_action :set_calendar_event, only: [ :show, :edit, :update, :destroy ]

  def index
    # Get events from Google Calendar
    auth = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: CalendarCredentials.credentials_io,
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
    service = GoogleCalendarApiService.new(auth)
    @google_events = service.get_events

    # Also get local calendar events for the calendar view
    @calendar_events = CalendarEvent.all
  end

  def show
  end

  def new
    @calendar_event = CalendarEvent.new

    # Pre-populate with date if provided
    if params[:calendar_event] && params[:calendar_event][:start_time]
      @calendar_event.start_time = params[:calendar_event][:start_time]
      @calendar_event.end_time = @calendar_event.start_time + 1.hour
    end
  end

  def create
    @calendar_event = CalendarEvent.new(calendar_event_params)

    if @calendar_event.save
      Rails.logger.info "Event saved successfully"
      # Try to sync with Google Calendar
      sync_to_google_calendar(@calendar_event, :create)

      redirect_to calendar_index_path, notice: "Event was successfully created."
    else
      Rails.logger.error "Event save failed: #{@calendar_event.errors.full_messages}"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Ensure times are in the correct timezone
    params_with_timezone = calendar_event_params
    if params_with_timezone[:start_time].present?
      params_with_timezone[:start_time] = params_with_timezone[:start_time].in_time_zone(Time.zone)
    end
    if params_with_timezone[:end_time].present?
      params_with_timezone[:end_time] = params_with_timezone[:end_time].in_time_zone(Time.zone)
    end

    if @calendar_event.update(params_with_timezone)
      # Try to sync with Google Calendar
      sync_to_google_calendar(@calendar_event, :update)

      redirect_to calendar_index_path, notice: "Event was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Try to delete from Google Calendar first
    sync_to_google_calendar(@calendar_event, :delete)

    @calendar_event.destroy
    redirect_to calendar_index_path, notice: "Event was successfully deleted."
  end

  private

  def target_timezone
    # TODO: Make this configurable by user
    "America/Los_Angeles"
  end

  def set_calendar_event
    @calendar_event = CalendarEvent.find(params[:id])
  end

  def calendar_event_params
    params.require(:calendar_event).permit(:title, :description, :start_time, :end_time, :location)
  end

  def sync_to_google_calendar(event, action)
    begin
      # Get service with write permissions
      auth = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: CalendarCredentials.credentials_io,
        scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
      service = GoogleCalendarApiService.new(auth)

      case action
      when :create
        create_google_event(service, event)
      when :update
        update_google_event(service, event)
      when :delete
        delete_google_event(service, event)
      else
        Rails.logger.error "Unexpected action received in sync_to_google_calendar: #{action.inspect}"
      end
    rescue => e
      Rails.logger.error "Failed to sync with Google Calendar: #{e.message}"
      # Don't fail the local operation if Google sync fails
    end
  end

  def create_google_event(service, event)
    # Convert times to the target timezone
    local_start_time = event.start_time.in_time_zone(target_timezone)
    local_end_time = event.end_time.in_time_zone(target_timezone)

    google_event = Google::Apis::CalendarV3::Event.new(
      summary: event.title,
      description: event.description,
      location: event.location,
      start: {
        date_time: local_start_time.strftime("%Y-%m-%dT%H:%M:%S"),
        time_zone: target_timezone
      },
      end: {
        date_time: local_end_time.strftime("%Y-%m-%dT%H:%M:%S"),
        time_zone: target_timezone
      }
    )

    result = service.calendar_service.insert_event(ENV["GOOGLE_CALENDAR_ID"], google_event)
    event.update_column(:google_event_id, result.id) if result.id
  end

  def update_google_event(service, event)
    return unless event.google_event_id

    # Convert times to the target timezone
    local_start_time = event.start_time.in_time_zone(target_timezone)
    local_end_time = event.end_time.in_time_zone(target_timezone)

    google_event = Google::Apis::CalendarV3::Event.new(
      summary: event.title,
      description: event.description,
      location: event.location,
      start: {
        date_time: local_start_time.strftime("%Y-%m-%dT%H:%M:%S"),
        time_zone: target_timezone
      },
      end: {
        date_time: local_end_time.strftime("%Y-%m-%dT%H:%M:%S"),
        time_zone: target_timezone
      }
    )

    service.calendar_service.update_event(ENV["GOOGLE_CALENDAR_ID"], event.google_event_id, google_event)
  end

  def delete_google_event(service, event)
    return unless event.google_event_id

    service.calendar_service.delete_event(ENV["GOOGLE_CALENDAR_ID"], event.google_event_id)
  end
end
