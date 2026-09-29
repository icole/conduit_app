# Push reminders, from 8am in each community's time zone: "Due today" for
# open tasks due today, and "Overdue" the morning after a task was due if
# it's still open. Runs hourly; each person on a task gets each reminder once
# (stamped on their assignment), so a missed run catches up later that day.
#
# And "Needs someone" for open work nobody is on that's due within two days,
# to everyone (a governance role's work only to its holders; not to whoever
# released it), once per task. The chat post when someone releases a task
# stays the first, social signal; this is the nudge if nobody's taken it.
class TaskRemindersJob < ApplicationJob
  queue_as :default

  REMINDER_HOUR = 8
  UNCLAIMED_DAYS_AHEAD = 2

  def perform
    Community.active.find_each do |community|
      now = Time.current.in_time_zone(community.time_zone)
      next if now.hour < REMINDER_HOUR

      ActsAsTenant.with_tenant(community) do
        remind(due_on: now.to_date, stamp: :due_reminder_sent_at) { |task, user| TaskPush.due_today(task, user) }
        remind(due_on: now.to_date - 1, stamp: :overdue_reminder_sent_at) { |task, user| TaskPush.overdue(task, user) }
        remind_unclaimed(now.to_date)
      end
    end
  end

  private

  def remind_unclaimed(today)
    tasks = Task.available.where(due_date: today..(today + UNCLAIMED_DAYS_AHEAD), unclaimed_reminder_sent_at: nil)
      .includes(workstream: { owners: :push_devices }).reorder(nil).to_a
    return if tasks.empty?

    everyone = User.includes(:push_devices).to_a
    tasks.each do |task|
      people = task.workstream.governance? ? task.workstream.owners : everyone
      people.each { |person| TaskPush.unclaimed(task, person) unless person.id == task.released_by_id }
      task.update_columns(unclaimed_reminder_sent_at: Time.current)
    end
  end

  def remind(due_on:, stamp:)
    TaskAssignment.where(stamp => nil).joins(:task).merge(Task.open.where(due_date: due_on))
      .includes(:task, user: :push_devices).find_each do |assignment|
        yield assignment.task, assignment.user
        assignment.update_columns(stamp => Time.current)
      end
  end
end
