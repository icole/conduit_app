# Push reminders, from 8am in each community's time zone: "Due today" for
# open tasks due today, and "Overdue" the morning after a task was due if
# it's still open. Runs hourly; each person on a task gets each reminder once
# (stamped on their assignment), so a missed run catches up later that day.
class TaskRemindersJob < ApplicationJob
  queue_as :default

  REMINDER_HOUR = 8

  def perform
    Community.active.find_each do |community|
      now = Time.current.in_time_zone(community.time_zone)
      next if now.hour < REMINDER_HOUR

      ActsAsTenant.with_tenant(community) do
        remind(due_on: now.to_date, stamp: :due_reminder_sent_at) { |task, user| TaskPush.due_today(task, user) }
        remind(due_on: now.to_date - 1, stamp: :overdue_reminder_sent_at) { |task, user| TaskPush.overdue(task, user) }
      end
    end
  end

  private

  def remind(due_on:, stamp:)
    TaskAssignment.where(stamp => nil).joins(:task).merge(Task.open.where(due_date: due_on))
      .includes(:task, user: :push_devices).find_each do |assignment|
        yield assignment.task, assignment.user
        assignment.update_columns(stamp => Time.current)
      end
  end
end
