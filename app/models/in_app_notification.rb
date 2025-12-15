class InAppNotification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :title, presence: true
  validates :notification_type, presence: true

  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc).limit(50) }
  scope :for_meals, -> { where(notification_type: %w[meal_reminder rsvp_deadline cook_assigned rsvps_closed]) }

  TYPES = {
    meal_reminder: "meal_reminder",
    rsvp_deadline: "rsvp_deadline",
    cook_assigned: "cook_assigned",
    rsvps_closed: "rsvps_closed",
    general: "general"
  }.freeze

  def mark_as_read!
    update!(read: true, read_at: Time.current) unless read?
  end

  def unread?
    !read?
  end

  def time_ago
    time_diff = Time.current - created_at
    if time_diff < 1.minute
      "just now"
    elsif time_diff < 1.hour
      "#{(time_diff / 1.minute).to_i}m ago"
    elsif time_diff < 1.day
      "#{(time_diff / 1.hour).to_i}h ago"
    elsif time_diff < 1.week
      "#{(time_diff / 1.day).to_i}d ago"
    else
      created_at.strftime("%b %d")
    end
  end

  def icon_class
    case notification_type
    when "meal_reminder" then "text-info"
    when "rsvp_deadline" then "text-warning"
    when "cook_assigned" then "text-success"
    when "rsvps_closed" then "text-primary"
    else "text-base-content"
    end
  end
end
