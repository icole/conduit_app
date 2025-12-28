# frozen_string_literal: true

class CalendarEventsController < ApplicationController
  before_action :set_calendar_event, only: [ :show, :update ]
  before_action :set_calendar_event_for_edit, only: [ :edit ]
  before_action :set_calendar_event_for_destroy, only: [ :destroy ]

  def index
    # Get events from Google Calendar
    auth = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: CalendarCredentials.credentials_io,
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
    service = GoogleCalendarApiService.new(auth)
    google_events_result = service.get_events

    # Get local calendar events
    local_events = CalendarEvent.all

    # Convert Google events to a format compatible with the calendar view
    @google_events = if google_events_result[:status] == :success
      google_events_result[:events].map do |event|
        OpenStruct.new(
          id: event[:id],
          title: event[:summary] || "Untitled Event",
          description: event[:description],
          location: event[:location],
          start_time: event[:start_time],
          end_time: event[:end_time],
          all_day: event[:all_day],
          google_event_id: event[:id],
          google_event: true,
          time_range: format_time_range(event[:start_time], event[:end_time], event[:all_day])
        )
      end
    else
      Rails.logger.error "Failed to load Google Calendar events: #{google_events_result[:error]}"
      []
    end

    # Combine both types of events for the calendar display
    @calendar_events = (local_events.to_a + @google_events).sort_by(&:start_time)
  end

  def show
    # Preload associations for the show page
    @calendar_event = CalendarEvent.includes(:documents, :decisions).find(params[:id])
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

      redirect_to calendar_event_path(@calendar_event), notice: "Event was successfully created."
    else
      Rails.logger.error "Event save failed: #{@calendar_event.errors.full_messages}"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # If google_event_id is provided, import it first
    if params[:google_event_id].present?
      import_google_event(params[:google_event_id])
    end

    # Log the times for debugging
    if @calendar_event
      Rails.logger.info "Event times - start: #{@calendar_event.start_time} (#{@calendar_event.start_time.zone}), end: #{@calendar_event.end_time} (#{@calendar_event.end_time.zone})"
      Rails.logger.info "Rails time zone: #{Time.zone}, target timezone: #{target_timezone}"
    end
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

      redirect_to calendar_event_path(@calendar_event), notice: "Event was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if params[:google_event_id].present?
      # Deleting a Google Calendar event - delete from Google Calendar
      delete_google_event_only(params[:google_event_id])
    else
      # Deleting a local event - delete both local and Google (if synced)
      sync_to_google_calendar(@calendar_event, :delete)
      @calendar_event.discard
    end

    redirect_to calendar_index_path, notice: "Event was successfully deleted."
  end

  def import_from_google
    google_event_id = params[:google_event_id]

    # Get the Google Calendar event details
    begin
      auth = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: CalendarCredentials.credentials_io,
        scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
      service = GoogleCalendarApiService.new(auth)
      google_event_result = service.get_event(ENV["GOOGLE_CALENDAR_ID"], google_event_id)

      if google_event_result[:error]
        raise StandardError, google_event_result[:error]
      end

      google_event_data = google_event_result

      # Convert Google event to local CalendarEvent
      @calendar_event = CalendarEvent.new(
        title: google_event_data[:summary] || "Untitled Event",
        description: google_event_data[:description],
        location: google_event_data[:location],
        google_event_id: google_event_data[:id],
        start_time: google_event_data[:start_time],
        end_time: google_event_data[:end_time]
      )

      if @calendar_event.save
        redirect_to calendar_event_path(@calendar_event)
      else
        redirect_to calendar_index_path, alert: "Failed to import event: #{@calendar_event.errors.full_messages.join(', ')}"
      end
    rescue => e
      Rails.logger.error "Failed to import Google Calendar event: #{e.message}"
      redirect_to calendar_index_path, alert: "Failed to import event from Google Calendar"
    end
  end

  private

  def format_time_range(start_time, end_time, all_day)
    return "All Day" if all_day

    if start_time.to_date == end_time.to_date
      # Same day - show date with time range
      "#{start_time.strftime('%b %d, %Y')} • #{start_time.strftime('%l:%M %p')} - #{end_time.strftime('%l:%M %p')}"
    else
      # Multi-day event
      "#{start_time.strftime('%b %d, %Y %l:%M %p')} - #{end_time.strftime('%b %d, %Y %l:%M %p')}"
    end
  end

  def target_timezone
    # TODO: Make this configurable by user
    "America/Los_Angeles"
  end

  def set_calendar_event
    @calendar_event = CalendarEvent.find(params[:id])
  end

  def set_calendar_event_for_edit
    if params[:id].present?
      # Editing existing local event
      @calendar_event = CalendarEvent.find(params[:id])
    elsif params[:google_event_id].present?
      # Will be set by import_google_event in the edit action
      @calendar_event = nil
    else
      # No ID provided
      redirect_to calendar_index_path, alert: "No event specified"
    end
  end

  def set_calendar_event_for_destroy
    if params[:id].present?
      # Deleting existing local event
      @calendar_event = CalendarEvent.find(params[:id])
    elsif params[:google_event_id].present?
      # Deleting Google Calendar event - no local event needed
      @calendar_event = nil
    else
      # No ID provided
      redirect_to calendar_index_path, alert: "No event specified"
    end
  end

  def import_google_event(google_event_id)
    begin
      auth = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: CalendarCredentials.credentials_io,
        scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
      service = GoogleCalendarApiService.new(auth)
      google_event_result = service.get_event(ENV["GOOGLE_CALENDAR_ID"], google_event_id)

      if google_event_result[:error]
        raise StandardError, google_event_result[:error]
      end

      # Convert Google event to local CalendarEvent with timezone conversion
      start_time_local = google_event_result[:start_time].in_time_zone(target_timezone)
      end_time_local = google_event_result[:end_time].in_time_zone(target_timezone)

      @calendar_event = CalendarEvent.new(
        title: google_event_result[:summary] || "Untitled Event",
        description: google_event_result[:description],
        location: google_event_result[:location],
        google_event_id: google_event_result[:id],
        start_time: start_time_local,
        end_time: end_time_local
      )

      if @calendar_event.save
        # Update params[:id] so the form and other actions work correctly
        params[:id] = @calendar_event.id.to_s
      else
        redirect_to calendar_index_path, alert: "Failed to import event: #{@calendar_event.errors.full_messages.join(', ')}"
        nil
      end
    rescue => e
      Rails.logger.error "Failed to import Google Calendar event: #{e.message}"
      redirect_to calendar_index_path, alert: "Failed to import event from Google Calendar"
    end
  end

  def delete_google_event_only(google_event_id)
    begin
      auth = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: CalendarCredentials.credentials_io,
        scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
      service = GoogleCalendarApiService.new(auth)

      # Delete the event from Google Calendar
      service.calendar_service.delete_event(ENV["GOOGLE_CALENDAR_ID"], google_event_id)

      Rails.logger.info "Successfully deleted Google Calendar event: #{google_event_id}"
    rescue => e
      Rails.logger.error "Failed to delete Google Calendar event: #{e.message}"
      # Don't fail the operation - just log the error
    end
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
