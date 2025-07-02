class AddAssignedToUserIdToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :assigned_to_user_id, :integer
    add_index :tasks, :assigned_to_user_id
    add_foreign_key :tasks, :users, column: :assigned_to_user_id
  end
end
