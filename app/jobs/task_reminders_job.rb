# The morning task push, from 8am in each community's time zone. Each person
# gets at most one, covering:
# - tasks they're on that are due today,
# - tasks they're on that were due yesterday and are still open (overdue),
# - open work nobody is on that's due within two days (to everyone; a
#   governance role's work only to its holders; not to whoever released it).
#
# Runs hourly. Each reminder is stamped once sent (on the person's assignment,
# or on the task for unclaimed work), so nothing repeats and a missed run
# catches up; something that becomes due later in the day comes on its own.
# The chat post when someone releases a task stays the first, social signal.
class TaskRemindersJob < ApplicationJob
  queue_as :default

  REMINDER_HOUR = 8
  UNCLAIMED_DAYS_AHEAD = 2

  Morning = Struct.new(:due, :overdue, :unclaimed) do
    def self.empty = new([], [], [])
  end

  def perform
    Community.active.find_each do |community|
      now = Time.current.in_time_zone(community.time_zone)
      next if now.hour < REMINDER_HOUR

      ActsAsTenant.with_tenant(community) { send_mornings(now.to_date) }
    end
  end

  private

  def send_mornings(today)
    mornings = Hash.new { |hash, user| hash[user] = Morning.empty }

    due = unsent_assignments(:due_reminder_sent_at, due_on: today)
    overdue = unsent_assignments(:overdue_reminder_sent_at, due_on: today - 1)
    due.each { |assignment| mornings[assignment.user].due << assignment.task }
    overdue.each { |assignment| mornings[assignment.user].overdue << assignment.task }

    unclaimed = unclaimed_tasks(today)
    if unclaimed.any?
      everyone = User.includes(:push_devices).to_a
      unclaimed.each do |task|
        people = task.workstream.governance? ? task.workstream.owners : everyone
        people.each { |person| mornings[person].unclaimed << task unless person.id == task.released_by_id }
      end
    end

    mornings.each { |user, morning| TaskPush.morning(user, **morning.to_h) }

    now = Time.current
    TaskAssignment.where(id: due.map(&:id)).update_all(due_reminder_sent_at: now)
    TaskAssignment.where(id: overdue.map(&:id)).update_all(overdue_reminder_sent_at: now)
    Task.where(id: unclaimed.map(&:id)).update_all(unclaimed_reminder_sent_at: now)
  end

  def unsent_assignments(stamp, due_on:)
    TaskAssignment.where(stamp => nil).joins(:task).merge(Task.open.where(due_date: due_on))
      .includes(:task, user: :push_devices).to_a
  end

  def unclaimed_tasks(today)
    Task.available.where(due_date: today..(today + UNCLAIMED_DAYS_AHEAD), unclaimed_reminder_sent_at: nil)
      .includes(workstream: { owners: :push_devices }).reorder(nil).to_a
  end
end
