class AddRoleIdToTasks < ActiveRecord::Migration[8.1]
  def change
    add_reference :tasks, :role, foreign_key: true
  end
end
