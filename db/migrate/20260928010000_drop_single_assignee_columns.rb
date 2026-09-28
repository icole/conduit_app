class DropSingleAssigneeColumns < ActiveRecord::Migration[8.1]
  # People on tasks moved to task_assignments and recurring_task_responsibles
  # (CreateTaskAssignments); the released code has ignored these since.
  def up
    remove_reference :tasks, :assigned_to_user, type: :integer, index: true, foreign_key: { to_table: :users }
    remove_reference :recurring_tasks, :default_responsible_user, index: true, foreign_key: { to_table: :users }
  end

  def down
    add_reference :tasks, :assigned_to_user, type: :integer, index: true, foreign_key: { to_table: :users }
    add_reference :recurring_tasks, :default_responsible_user, index: true, foreign_key: { to_table: :users }
    execute <<~SQL
      UPDATE tasks SET assigned_to_user_id = (
        SELECT user_id FROM task_assignments WHERE task_assignments.task_id = tasks.id ORDER BY id LIMIT 1
      )
    SQL
    execute <<~SQL
      UPDATE recurring_tasks SET default_responsible_user_id = (
        SELECT user_id FROM recurring_task_responsibles
        WHERE recurring_task_responsibles.recurring_task_id = recurring_tasks.id ORDER BY id LIMIT 1
      )
    SQL
  end
end
