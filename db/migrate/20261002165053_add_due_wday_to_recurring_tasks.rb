# The day of the week a weekly or every-two-weeks task falls due (Date#wday:
# 0 = Sunday). Sunday keeps existing tasks on their Monday-to-Sunday weeks.
class AddDueWdayToRecurringTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :recurring_tasks, :due_wday, :integer, null: false, default: 0
  end
end
