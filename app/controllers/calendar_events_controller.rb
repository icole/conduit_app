# frozen_string_literal: true

class CalendarEventsController < ApplicationController
  before_action :set_calendar_event, only: [ :show, :edit, :update, :destroy ]

  def index
    @calendar_events = CalendarEvent.all
  end

  def show
  end

  def new
    @calendar_event = CalendarEvent.new

    # Set the start_time if provided in params
    if params[:calendar_event] && params[:calendar_event][:start_time].present?
      @calendar_event.start_time = params[:calendar_event][:start_time]
    end
  end

  def edit
  end

  def create
    @calendar_event = CalendarEvent.new(calendar_event_params)

    if @calendar_event.save
      redirect_to calendar_index_path, notice: "Event was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @calendar_event.update(calendar_event_params)
      redirect_to calendar_index_path, notice: "Event was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @calendar_event.destroy
    redirect_to calendar_index_path, notice: "Event was successfully removed."
  end

  private

  def set_calendar_event
    @calendar_event = CalendarEvent.find(params[:id])
  end

  def calendar_event_params
    params.require(:calendar_event).permit(:title, :description, :start_time, :end_time)
  end
end
