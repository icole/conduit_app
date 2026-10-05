module NotificationsHelper
  KIND_ICONS = {
    "rsvp_deadline" => "calendar-days",
    "meal_reminder" => "clock",
    "cook_assigned" => "fire",
    "rsvps_closed" => "check-circle",
    "task_assigned" => "clipboard-document-check",
    "task_due" => "clipboard-document-check",
    "task_needs_someone" => "hand-raised"
  }.freeze

  # What the navbar's bell shows: settled once per request, so dealing with
  # something (an RSVP, a finished task) clears it on the next page
  def notification_bell
    @notification_bell ||= begin
      InAppNotification.settle_for(current_user)
      notifications = current_user.in_app_notifications.order(created_at: :desc)
      { needs_you: notifications.needs_you.limit(5).to_a, count: notifications.needs_you.count, updates: notifications.updates.limit(5).to_a }
    end
  end

  def notification_icon(notification)
    heroicon KIND_ICONS.fetch(notification.notification_type, "bell"), variant: :outline, options: { class: "h-5 w-5" }
  end
end
