class MealRsvp < ApplicationRecord
  belongs_to :meal
  belongs_to :user

  validates :status, presence: true, inclusion: { in: %w[attending declined maybe] }
  validates :guests_count, numericality: { greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: { scope: :meal_id, message: "has already RSVPed" }
  validate :rsvps_still_open, on: :create
  validate :user_is_not_cook

  scope :attending, -> { where(status: "attending") }
  scope :declined, -> { where(status: "declined") }
  scope :maybe, -> { where(status: "maybe") }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_guests, -> { attending.where("guests_count > 0") }

  STATUSES = {
    attending: "attending",
    declined: "declined",
    maybe: "maybe"
  }.freeze

  def attending?
    status == "attending"
  end

  def declined?
    status == "declined"
  end

  def maybe?
    status == "maybe"
  end

  def total_count
    attending? ? 1 + guests_count : 0
  end

  def status_display
    case status
    when "attending" then "Attending"
    when "declined" then "Not Attending"
    when "maybe" then "Maybe"
    else status&.humanize
    end
  end

  def guests_display
    return nil if guests_count.zero?
    guests_count == 1 ? "+1 guest" : "+#{guests_count} guests"
  end

  private

  def rsvps_still_open
    return if meal.nil?
    if meal.rsvps_closed?
      errors.add(:base, "RSVPs are closed for this meal")
    end
  end

  def user_is_not_cook
    return if meal.nil? || user.nil?
    if meal.user_is_cook?(user)
      errors.add(:base, "Cooks don't need to RSVP - you're already counted as attending")
    end
  end
end
