class ChangeTaskStatusPendingToActive < ActiveRecord::Migration[8.0]
  def up
    # Update all tasks with 'pending' status to 'active' status
    execute "UPDATE tasks SET status = 'active' WHERE status = 'pending'"
  end

  def down
    # Revert all tasks with 'active' status back to 'pending' status
    # Note: This assumes all current 'active' tasks were originally 'pending'
    # In practice, you might want to be more selective about this rollback
    execute "UPDATE tasks SET status = 'pending' WHERE status = 'active'"
  end
end
