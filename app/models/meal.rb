class Meal < ApplicationRecord
  include Discardable

  acts_as_tenant :community

  belongs_to :meal_schedule, optional: true
  has_many :meal_cooks, -> { order(:id) }, dependent: :destroy
  has_many :cooks, through: :meal_cooks, source: :user
  has_many :meal_rsvps, dependent: :destroy
  has_many :attendees, through: :meal_rsvps, source: :user
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy

  validates :scheduled_at, presence: true
  validates :rsvp_deadline, presence: true
  validates :status, presence: true, inclusion: { in: %w[upcoming rsvps_closed completed cancelled] }
  validate :rsvp_deadline_before_meal

  before_validation :generate_title, if: -> { title.blank? && scheduled_at.present? }

  cascade_discard :comments

  after_save :sync_to_google_calendar, if: :should_sync_to_calendar?
  after_discard :delete_from_google_calendar

  scope :upcoming, -> { where(status: %w[upcoming rsvps_closed]).where("scheduled_at > ?", Time.current).order(:scheduled_at) }
  scope :past, -> { where("scheduled_at < ?", Time.current).order(scheduled_at: :desc) }
  scope :needs_cooks, -> { upcoming.left_joins(:meal_cooks).group(:id).having("COUNT(meal_cooks.id) = 0") }
  scope :for_week, ->(date) { where(scheduled_at: date.beginning_of_week..date.end_of_week).order(:scheduled_at) }
  scope :for_month, ->(date) { where(scheduled_at: date.beginning_of_month..date.end_of_month).order(:scheduled_at) }
  scope :rsvp_open, -> { where(rsvps_closed: false).where("rsvp_deadline > ?", Time.current) }
  scope :recent, -> { order(created_at: :desc) }

  # Status helpers
  def upcoming?
    status == "upcoming"
  end

  def rsvps_open?
    !rsvps_closed && Time.current < rsvp_deadline
  end

  def rsvps_closed?
    rsvps_closed || Time.current >= rsvp_deadline
  end

  def completed?
    status == "completed"
  end

  def cancelled?
    status == "cancelled"
  end

  # Time helpers
  def scheduled_date
    scheduled_at.to_date
  end

  def time_display
    scheduled_at.strftime("%l:%M %p").strip
  end

  def date_display
    scheduled_at.strftime("%A, %B %d")
  end

  def full_display
    "#{date_display} at #{time_display}"
  end

  def time_until_rsvp_close
    return nil if rsvps_closed?
    rsvp_deadline - Time.current
  end

  # Cook helpers
  def head_cook
    meal_cooks.find_by(role: "head_cook")&.user
  end

  def helpers
    meal_cooks.where(role: "helper").includes(:user).map(&:user)
  end

  def needs_head_cook?
    meal_cooks.where(role: "head_cook").empty?
  end

  def cook_slots_available?
    return true unless meal_schedule
    meal_cooks.count < meal_schedule.max_cooks
  end

  def user_is_cook?(user)
    return false unless user
    meal_cooks.exists?(user: user)
  end

  def cook_for(user)
    meal_cooks.find_by(user: user)
  end

  # RSVP helpers
  def rsvp_for(user)
    return nil unless user
    meal_rsvps.find_by(user: user)
  end

  def user_rsvped?(user)
    return false unless user
    meal_rsvps.exists?(user: user)
  end

  def user_attending?(user)
    return false unless user
    meal_rsvps.attending.exists?(user: user)
  end

  def user_maybe?(user)
    return false unless user
    meal_rsvps.maybe.exists?(user: user)
  end

  def user_declined?(user)
    return false unless user
    meal_rsvps.declined.exists?(user: user)
  end

  def total_attendees
    cooks_count = meal_cooks.count
    rsvps_attending = meal_rsvps.attending.sum { |r| 1 + r.guests_count }
    cooks_count + rsvps_attending
  end

  def total_plates
    # Total plates needed: cooks + attending (with guests) + late plates
    cooks_count = meal_cooks.count
    attending_plates = meal_rsvps.attending.sum { |r| 1 + r.guests_count }
    late_plates = meal_rsvps.late_plate.count
    cooks_count + attending_plates + late_plates
  end

  def late_plate_count
    meal_rsvps.late_plate.count
  end

  def attending_count
    meal_rsvps.attending.count
  end

  def guests_count
    meal_rsvps.attending.sum(:guests_count)
  end

  # Status transitions
  def close_rsvps!
    update!(rsvps_closed: true, status: "rsvps_closed")
  end

  def complete!
    update!(status: "completed")
  end

  def cancel!
    update!(status: "cancelled")
  end

  def reopen_rsvps!
    new_deadline = rsvp_deadline
    if rsvp_deadline < Time.current
      # Set deadline to 1 hour before meal, or 1 hour from now (whichever is later)
      new_deadline = [ scheduled_at - 1.hour, 1.hour.from_now ].max
    end
    update!(rsvps_closed: false, status: "upcoming", rsvp_deadline: new_deadline)
  end

  # For likes/comments interface
  def likes_count
    likes.count
  end

  def liked_by?(user)
    return false unless user
    likes.exists?(user: user)
  end

  def comments_count
    comments.count
  end

  # Check if synced with Google Calendar
  def synced_with_google?
    google_event_id.present?
  end

  # Display title with cook names
  def display_title
    first_names = cooks.map { |cook| cook.name.split.first }
    case first_names.size
    when 0
      "Community Meal"
    when 1
      "Community Meal (#{first_names.first})"
    when 2
      "Community Meal (#{first_names.first} & #{first_names.second})"
    else
      "Community Meal (#{first_names[0..-2].join(', ')} & #{first_names.last})"
    end
  end

  private

  def generate_title
    self.title = scheduled_at.strftime("%A, %B %-d")
  end

  def rsvp_deadline_before_meal
    return unless scheduled_at && rsvp_deadline
    if rsvp_deadline >= scheduled_at
      errors.add(:rsvp_deadline, "must be before the meal time")
    end
  end

  def should_sync_to_calendar?
    saved_change_to_title? || saved_change_to_scheduled_at? || saved_change_to_description? || !synced_with_google?
  end

  def sync_to_google_calendar
    MealCalendarSyncJob.perform_later(id)
  end

  def delete_from_google_calendar
    return unless google_event_id.present?
    MealCalendarSyncJob.perform_later(id, action: "delete")
  end
end
