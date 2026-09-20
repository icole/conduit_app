class RemoveChores < ActiveRecord::Migration[8.1]
  # Removes the Chores feature. Deletes data: chores and their comments, likes
  # and audit versions. Production held 33 chores (all "proposed", imported
  # July 2025, never assigned or completed) at the time of writing.
  def up
    execute "DELETE FROM likes WHERE likeable_type = 'Chore'"
    execute "DELETE FROM likes WHERE likeable_type = 'Comment' AND likeable_id IN (SELECT id FROM comments WHERE commentable_type = 'Chore')"
    execute "DELETE FROM comments WHERE commentable_type = 'Chore'"
    execute "DELETE FROM versions WHERE item_type IN ('Chore', 'ChoreAssignment', 'ChoreCompletion')"
    drop_table :chore_completions, if_exists: true
    drop_table :chore_assignments, if_exists: true
    drop_table :chores, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Chores were removed along with their data"
  end
end
