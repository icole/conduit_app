class AddUnclaimedReminderSentAtToTasks < ActiveRecord::Migration[8.1]
  # When the "Needs someone" push went out for a task nobody is on
  # (TaskRemindersJob), so it goes out once.
  def change
    add_column :tasks, :unclaimed_reminder_sent_at, :datetime
  end
end
