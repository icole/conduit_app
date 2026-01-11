# frozen_string_literal: true

class CalendarController < ApplicationController
  def index
    # Set the calendar date if provided
    begin
      @date = params[:start_date] ? Date.parse(params[:start_date]) : Date.current
    rescue Date::Error
      @date = Date.current
    end

    # Create filtered params for simple_calendar
    @calendar_params = params.except(:start_date, :date).to_unsafe_h

    # Get Google Calendar events and convert them to objects compatible with simple_calendar
    begin
      if !Rails.env.test?
        auth = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: CalendarCredentials.credentials_io,
          scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
        service = GoogleCalendarApiService.new(auth)
        @google_events_result = service.get_events

        # Convert Google Calendar events to objects that work with simple_calendar
        if @google_events_result[:status] == :success && @google_events_result[:events].any?
          @calendar_events = @google_events_result[:events].map do |event|
            # For all-day events, set end_time to start_time so they only appear on one day
            start_time = event[:start_time]
            end_time = event[:all_day] ? start_time : event[:end_time]

            # Create an object that mimics CalendarEvent for simple_calendar compatibility
            obj = Object.new
            obj.define_singleton_method(:title) { event[:summary] || "Untitled Event" }
            obj.define_singleton_method(:start_time) { start_time }
            obj.define_singleton_method(:end_time) { end_time }
            obj.define_singleton_method(:location) { event[:location] }
            obj.define_singleton_method(:google_event) { true }
            obj.define_singleton_method(:google_event_id) { event[:id] }
            obj.define_singleton_method(:all_day) { event[:all_day] }
            obj.define_singleton_method(:respond_to?) { |method| [ :title, :start_time, :end_time, :location, :google_event, :google_event_id, :all_day ].include?(method.to_sym) }
            obj.define_singleton_method(:time_range) do
              if event[:all_day]
                "#{start_time.strftime('%b %d, %Y')} • All Day"
              elsif start_time.to_date == end_time.to_date
                "#{start_time.strftime('%b %d, %Y')} • #{start_time.strftime('%l:%M %p')} - #{end_time.strftime('%l:%M %p')}"
              else
                "#{start_time.strftime('%b %d, %Y %l:%M %p')} - #{end_time.strftime('%b %d, %Y %l:%M %p')}"
              end
            end
            obj
          end.sort_by(&:start_time)
        else
          @calendar_events = []
        end
      else
        @google_events_result = { events: [], status: :success }
        @calendar_events = []
      end
    rescue StandardError => e
      Rails.logger.error "Failed to load Google Calendar events: #{e.message}"
      Rails.logger.error e.backtrace
      @google_events_result = { events: [], status: :error }
      @calendar_events = []
    end
  end

  def show_event
    # Get the event ID and date
    @event_id = params[:event_id]
    @date = params[:start_date] ? Date.parse(params[:start_date]) : Date.current

    # Set a flash message that will trigger the modal
    flash[:open_event_modal] = @event_id

    # Redirect to the calendar page
    redirect_to calendar_index_path(start_date: @date.to_s)
  end

  private

  def format_google_event_time_range(event)
    start_time = event[:start_time]
    end_time = event[:end_time]

    return "" unless start_time && end_time

    if start_time.to_date == end_time.to_date
      # Same day - show date with time range
      "#{start_time.strftime('%b %d, %Y')} • #{start_time.strftime('%l:%M %p')} - #{end_time.strftime('%l:%M %p')}"
    else
      # Multi-day event
      "#{start_time.strftime('%b %d, %Y %l:%M %p')} - #{end_time.strftime('%b %d, %Y %l:%M %p')}"
    end
  end
end
