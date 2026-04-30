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

    # Set up calendar sharing variables for subscribe button
    setup_calendar_sharing_variables

    # Calculate month boundaries to include past events
    start_of_month = @date.beginning_of_month.beginning_of_day
    end_of_month = @date.end_of_month.end_of_day

    # Get Google Calendar events and convert them to objects compatible with simple_calendar
    begin
      if !Rails.env.test?
        service = GoogleCalendarApiService.from_service_account_with_acl_scope

        # Fetch events for the calendar grid (current month)
        @google_events_result = service.get_events(
          time_min: start_of_month,
          time_max: end_of_month
        )

        # Fetch upcoming events separately (next 90 days from now)
        upcoming_result = service.get_events(
          time_min: Time.current,
          max_results: 5
        )

        # Convert Google Calendar events to objects that work with simple_calendar
        if @google_events_result[:status] == :success && @google_events_result[:events].any?
          @calendar_events = build_calendar_event_objects(@google_events_result[:events])
        else
          @calendar_events = []
        end

        # Build upcoming events list from the separate query
        if upcoming_result[:status] == :success && upcoming_result[:events].any?
          @upcoming_events = build_calendar_event_objects(upcoming_result[:events])
        else
          @upcoming_events = []
        end
      else
        @google_events_result = { events: [], status: :success }
        @calendar_events = []
        @upcoming_events = []
      end
    rescue StandardError => e
      Rails.logger.error "Failed to load Google Calendar events: #{e.message}"
      Rails.logger.error e.backtrace
      @google_events_result = { events: [], status: :error }
      @calendar_events = []
      @upcoming_events = []
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

  def setup_calendar_sharing_variables
    calendar_id = current_community.google_calendar_id
    @calendar_already_shared = calendar_id.present? && CalendarShare.calendar_shared_with_user?(calendar_id, current_user)

    @google_calendar_configured = begin
      defined?(CalendarCredentials) && CalendarCredentials.configured? && current_community.google_calendar_id.present?
    rescue
      false
    end
  end

  def build_calendar_event_objects(events)
    events.map do |event|
      start_time = event[:start_time]
      end_time = event[:all_day] ? start_time : event[:end_time]

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
  end

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
