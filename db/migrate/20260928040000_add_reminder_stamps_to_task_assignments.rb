class AddReminderStampsToTaskAssignments < ActiveRecord::Migration[8.1]
  # When each person on a task got its "due today" and "overdue" push
  # reminders (TaskRemindersJob), so they go out once.
  def change
    add_column :task_assignments, :due_reminder_sent_at, :datetime
    add_column :task_assignments, :overdue_reminder_sent_at, :datetime
  end
end
