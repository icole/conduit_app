# frozen_string_literal: true

class CalendarEventsController < ApplicationController
  before_action :set_google_event, only: [ :show, :edit ]

  def new
    @event = OpenStruct.new(title: nil, description: nil, location: nil, start_time: nil, end_time: nil)

    if params.dig(:calendar_event, :start_time)
      @event.start_time = Time.zone.parse(params[:calendar_event][:start_time])
      @event.end_time = @event.start_time + 1.hour
    end
  end

  def create
    result = google_service.create_event(
      calendar_id: calendar_id,
      title: event_params[:title],
      start_time: Time.zone.parse(event_params[:start_time]),
      end_time: Time.zone.parse(event_params[:end_time]),
      description: event_params[:description] || "",
      location: event_params[:location] || ""
    )

    if result[:status] == :success
      redirect_to calendar_event_path(google_event_id: result[:event_id]),
                  notice: "Event was successfully created."
    else
      @event = OpenStruct.new(event_params)
      flash.now[:alert] = "Failed to create event: #{result[:error]}"
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    result = google_service.update_event(
      calendar_id: calendar_id,
      event_id: params[:google_event_id],
      title: event_params[:title],
      start_time: Time.zone.parse(event_params[:start_time]),
      end_time: Time.zone.parse(event_params[:end_time]),
      description: event_params[:description] || "",
      location: event_params[:location] || ""
    )

    if result[:status] == :success
      redirect_to calendar_event_path(google_event_id: params[:google_event_id]),
                  notice: "Event was successfully updated."
    else
      @event = OpenStruct.new(event_params.merge(google_event_id: params[:google_event_id]))
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
      time_range: format_time_range(data[:start_time], data[:end_time], data[:all_day]),
      duration_hours: data[:end_time] && data[:start_time] ? ((data[:end_time] - data[:start_time]) / 1.hour).round(1) : nil
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
    ENV["GOOGLE_CALENDAR_ID"]
  end

  def event_params
    params.require(:calendar_event).permit(:title, :description, :start_time, :end_time, :location)
  end
end
