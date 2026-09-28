# frozen_string_literal: true

# Events live in the community's Google Calendar. There's no page per event:
# the calendar's popup shows one, and saving goes back to it.
class CalendarEventsController < ApplicationController
  before_action :set_google_event, only: [ :show, :edit ]

  def new
    # A day clicked on the calendar, or else the next full hour today
    start_time = Time.zone.parse(params.dig(:calendar_event, :start_time).to_s) if params.dig(:calendar_event, :start_time)
    start_time ||= Time.current.beginning_of_hour + 1.hour
    @event = OpenStruct.new(title: nil, description: nil, location: nil, start_time: start_time, end_time: start_time + 1.hour)
  end

  def create
    start_time = parse_event_datetime(:start)
    end_time = parse_event_datetime(:end)

    if (problem = time_problem(start_time, end_time))
      @event = build_event_from_params
      flash.now[:alert] = problem
      return render :new, status: :unprocessable_entity
    end

    result = google_service.create_event(
      calendar_id: calendar_id,
      title: event_params[:title],
      start_time: start_time,
      end_time: end_time,
      description: event_params[:description] || "",
      location: event_params[:location] || ""
    )

    if result[:status] == :success
      redirect_to_event_on_calendar result[:event_id], start_time, notice: "Event created."
    else
      @event = build_event_from_params
      flash.now[:alert] = "Failed to create event: #{result[:error]}"
      render :new, status: :unprocessable_entity
    end
  end

  # Old links to an event's page open its popup on the calendar instead
  def show
    redirect_to_event_on_calendar @event.google_event_id, @event.start_time
  end

  def edit
  end

  def update
    start_time = parse_event_datetime(:start)
    end_time = parse_event_datetime(:end)

    if (problem = time_problem(start_time, end_time))
      @event = build_event_from_params(google_event_id: params[:google_event_id])
      flash.now[:alert] = problem
      return render :edit, status: :unprocessable_entity
    end

    result = google_service.update_event(
      calendar_id: calendar_id,
      event_id: params[:google_event_id],
      title: event_params[:title],
      start_time: start_time,
      end_time: end_time,
      description: event_params[:description] || "",
      location: event_params[:location] || ""
    )

    if result[:status] == :success
      redirect_to_event_on_calendar params[:google_event_id], start_time, notice: "Event updated."
    else
      @event = build_event_from_params(google_event_id: params[:google_event_id])
      flash.now[:alert] = "Failed to update event: #{result[:error]}"
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    result = google_service.delete_event(
      calendar_id: calendar_id,
      event_id: params[:google_event_id]
    )

    if result[:status] == :success
      redirect_to calendar_index_path, notice: "Event was successfully deleted."
    else
      redirect_to calendar_index_path, alert: "Failed to delete event: #{result[:error]}"
    end
  end

  private

  def redirect_to_event_on_calendar(event_id, start_time, **flash_messages)
    flash[:open_event_modal] = event_id
    redirect_to calendar_index_path(start_date: start_time.to_date.to_s), **flash_messages
  end

  def time_problem(start_time, end_time)
    if start_time.nil? || end_time.nil?
      "Pick a date and a start and end time."
    elsif end_time <= start_time
      "The end needs to be after the start."
    end
  end

  def set_google_event
    result = google_service.get_event(calendar_id, params[:google_event_id])

    if result[:error]
      redirect_to calendar_index_path, alert: "Event not found."
      return
    end

    @event = build_event_struct(result)
  end

  def build_event_struct(data)
    OpenStruct.new(
      google_event_id: data[:id],
      title: data[:summary] || "Untitled Event",
      description: data[:description],
      location: data[:location],
      start_time: data[:start_time],
      end_time: data[:end_time],
      all_day: data[:all_day],
      html_link: data[:html_link],
      time_range: format_time_range(data[:start_time], data[:end_time], data[:all_day])
    )
  end

  def format_time_range(start_time, end_time, all_day)
    return "All Day" if all_day
    return "" unless start_time && end_time

    if start_time.to_date == end_time.to_date
      "#{start_time.strftime('%b %d, %Y')} • #{start_time.strftime('%l:%M %p')} - #{end_time.strftime('%l:%M %p')}"
    else
      "#{start_time.strftime('%b %d, %Y %l:%M %p')} - #{end_time.strftime('%b %d, %Y %l:%M %p')}"
    end
  end

  def google_service
    @google_service ||= GoogleCalendarApiService.from_service_account_with_acl_scope
  end

  def calendar_id
    ENV.fetch("GOOGLE_CALENDAR_ID")
  end

  def event_params
    params.require(:calendar_event).permit(:title, :description, :location,
      :start_date, :start_time_of_day, :end_date, :end_time_of_day,
      :start_time, :end_time)
  end

  # A one-day event only sends a start date; its end is on the same day
  def parse_event_datetime(prefix)
    date = event_params[:"#{prefix}_date"].presence || event_params[:start_date]
    time = event_params[:"#{prefix}_time_of_day"]
    return nil if date.blank? || time.blank?

    Time.zone.parse("#{date} #{time}")
  rescue ArgumentError
    nil
  end

  def build_event_from_params(**extra)
    start_time = parse_event_datetime(:start)
    end_time = parse_event_datetime(:end)
    OpenStruct.new(
      title: event_params[:title],
      description: event_params[:description],
      location: event_params[:location],
      start_time: start_time,
      end_time: end_time,
      **extra
    )
  end
end
