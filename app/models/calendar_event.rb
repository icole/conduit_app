# frozen_string_literal: true

class CalendarEvent < ApplicationRecord
  has_and_belongs_to_many :documents
  has_many :decisions, dependent: :nullify

  validates :title, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true

  # Ensure end_time is after start_time
  validate :end_time_after_start_time

  # Use simple_calendar convention for showing events on the calendar
  def start_time
    self[:start_time]
  end

  # Check if this event is synced with Google Calendar
  def synced_with_google?
    google_event_id.present?
  end

  # Generate a display time range
  def time_range
    if start_time.to_date == end_time.to_date
      # Same day - show date with time range
      "#{start_time.strftime('%b %d, %Y')} • #{start_time.strftime('%l:%M %p')} - #{end_time.strftime('%l:%M %p')}"
    else
      # Multi-day event
      "#{start_time.strftime('%b %d, %Y %l:%M %p')} - #{end_time.strftime('%b %d, %Y %l:%M %p')}"
    end
  end

  # Duration in hours
  def duration_hours
    ((end_time - start_time) / 1.hour).round(1)
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time

    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end
