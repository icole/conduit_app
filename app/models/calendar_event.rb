# frozen_string_literal: true

class CalendarEvent < ApplicationRecord
  validates :title, presence: true
  validates :start_time, presence: true

  # Use simple_calendar convention for showing events on the calendar
  def start_time
    self[:start_time]
  end
end
