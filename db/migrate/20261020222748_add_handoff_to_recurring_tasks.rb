class AddHandoffToRecurringTasks < ActiveRecord::Migration[8.1]
  def change
    add_reference :recurring_tasks, :handed_off_by, foreign_key: { to_table: :users, on_delete: :nullify }
    add_column :recurring_tasks, :handed_off_at, :datetime
  end
end
