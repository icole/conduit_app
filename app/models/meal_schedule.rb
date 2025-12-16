class MealSchedule < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many :meals, dependent: :destroy

  validates :name, presence: true
  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :start_time, presence: true
  validates :rsvp_deadline_hours, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :for_day, ->(day) { where(day_of_week: day) }
  scope :ordered, -> { order(:day_of_week, :start_time) }

  DAY_NAMES = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze

  def day_name
    DAY_NAMES[day_of_week]
  end

  def display_time
    start_time.strftime("%l:%M %p").strip
  end

  def display_schedule
    "#{day_name}s at #{display_time}"
  end

  def next_occurrence(from_date = Date.current)
    days_until = (day_of_week - from_date.wday) % 7
    days_until = 7 if days_until.zero? && Time.current > start_time_on(from_date)
    from_date + days_until.days
  end

  def start_time_on(date)
    Time.zone.local(date.year, date.month, date.day, start_time.hour, start_time.min)
  end

  def end_time_on(date)
    return nil unless end_time
    Time.zone.local(date.year, date.month, date.day, end_time.hour, end_time.min)
  end

  def rsvp_deadline_for(meal_datetime)
    meal_datetime - rsvp_deadline_hours.hours
  end

  def toggle_active!
    update!(active: !active)
  end

  def generate_meal_for_date(date)
    meal_datetime = start_time_on(date)

    meals.create!(
      title: "#{name} - #{date.strftime('%b %d')}",
      scheduled_at: meal_datetime,
      rsvp_deadline: rsvp_deadline_for(meal_datetime),
      location: location,
      status: "upcoming"
    )
  end
end
