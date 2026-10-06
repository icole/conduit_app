class InAppNotification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :title, presence: true
  validates :notification_type, presence: true

  # The apps' bell, live (settle_for's update_columns skip this)
  after_commit { BellBroadcastJob.for_users([ user_id ]) }

  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc).limit(50) }
  scope :for_meals, -> { where(notification_type: %w[meal_reminder rsvp_deadline cook_assigned rsvps_closed]) }
  # Not yet dealt with (CON-72); see NotificationKind
  scope :unresolved, -> { where(resolved_at: nil) }
  scope :needs_you, -> { unresolved.where(notification_type: NotificationKind.needing_you) }
  scope :updates, -> { where(notification_type: NotificationKind.updates) }

  # Marks as resolved whatever has been dealt with since. Run before showing
  # the bell; a member only ever has a handful unresolved.
  def self.settle_for(user)
    user.in_app_notifications.unresolved.includes(:notifiable).find_each do |notification|
      notification.update_columns(resolved_at: Time.current) if notification.addressed?
    end
  end

  def kind = NotificationKind.fetch(notification_type)

  # Its meal or task was deleted, or its kind's rule says so. Updates without
  # a rule are addressed by reading them (mark_as_read!).
  def addressed?
    return true if notifiable_type.present? && notifiable.nil?
    return false unless kind.addressed

    kind.addressed.call(self, notifiable)
  end

  TYPES = {
    meal_reminder: "meal_reminder",
    rsvp_deadline: "rsvp_deadline",
    cook_assigned: "cook_assigned",
    rsvps_closed: "rsvps_closed",
    general: "general"
  }.freeze

  # Where it leads, as a path on this site. Stored URLs may be full ones on a
  # community's domain; only the path is followed, so a notification can't
  # send anyone off-site
  def path
    return if action_url.blank?

    uri = URI.parse(action_url)
    path = uri.path.presence || "/"
    path.start_with?("/") && !path.start_with?("//") ? [ path, uri.query ].compact.join("?") : nil
  rescue URI::InvalidURIError
    nil
  end

  def mark_as_read!
    return if read?

    update!(read: true, read_at: Time.current, resolved_at: kind.needs_you? ? resolved_at : (resolved_at || Time.current))
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
