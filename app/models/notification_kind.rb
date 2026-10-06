# The kinds of notification, and for each, when what it asked of the member
# has been dealt with (CON-72). "Needs you" kinds count on the bell until
# then; updates only need reading. A notification whose meal or task has been
# deleted is addressed. Rules read the current state, so nothing has to
# remember to dismiss anything.
class NotificationKind
  Kind = Data.define(:key, :needs_you, :addressed) do
    def needs_you? = needs_you
  end

  def self.task_done_or_not_yours = ->(n, task) { task.status == "completed" || !task.assigned_to?(n.user) }
  def self.rsvped_or_closed = ->(n, meal) {
    meal.rsvps_closed? || meal.meal_rsvps.exists?(user_id: n.user_id) || meal.meal_cooks.exists?(user_id: n.user_id)
  }

  ALL = [
    # Both ask for an RSVP, and share one entry per meal (MealNotificationService)
    Kind.new("rsvp_deadline", true, rsvped_or_closed),
    Kind.new("meal_reminder", true, rsvped_or_closed),
    Kind.new("meal_needs_cook", true, ->(_n, meal) { !meal.needs_head_cook? || meal.cancelled? || meal.scheduled_at.past? }),
    Kind.new("task_assigned", true, task_done_or_not_yours),
    Kind.new("task_due", true, task_done_or_not_yours),
    Kind.new("task_needs_someone", true, ->(_n, task) { task.status == "completed" || task.assignees.any? }),
    Kind.new("cook_assigned", false, nil),
    Kind.new("rsvps_closed", false, nil),
    Kind.new("general", false, nil)
  ].index_by(&:key).freeze

  def self.fetch(key) = ALL.fetch(key, ALL.fetch("general"))
  def self.needing_you = ALL.values.select(&:needs_you?).map(&:key)
  def self.updates = ALL.values.reject(&:needs_you?).map(&:key)
end
