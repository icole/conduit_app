class Meal < ApplicationRecord
  belongs_to :meal_schedule, optional: true
  has_many :meal_cooks, dependent: :destroy
  has_many :cooks, through: :meal_cooks, source: :user
  has_many :meal_rsvps, dependent: :destroy
  has_many :attendees, through: :meal_rsvps, source: :user
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy

  validates :title, presence: true
  validates :scheduled_at, presence: true
  validates :rsvp_deadline, presence: true
  validates :status, presence: true, inclusion: { in: %w[upcoming rsvps_closed completed cancelled] }
  validate :rsvp_deadline_before_meal

  scope :upcoming, -> { where(status: "upcoming").where("scheduled_at > ?", Time.current).order(:scheduled_at) }
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
    update!(rsvps_closed: false, status: "upcoming")
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

  private

  def rsvp_deadline_before_meal
    return unless scheduled_at && rsvp_deadline
    if rsvp_deadline >= scheduled_at
      errors.add(:rsvp_deadline, "must be before the meal time")
    end
  end
end
