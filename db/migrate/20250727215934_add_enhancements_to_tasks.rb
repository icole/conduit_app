class AddEnhancementsToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :due_date, :date
    add_column :tasks, :priority_order, :integer
    add_index :tasks, :priority_order
    add_index :tasks, :due_date
  end
end
