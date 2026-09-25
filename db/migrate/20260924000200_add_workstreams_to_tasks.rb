class AddWorkstreamsToTasks < ActiveRecord::Migration[8.1]
  def up
    change_table :tasks, bulk: true do |t|
      t.references :workstream, foreign_key: true
      t.references :recurring_task, foreign_key: true
      t.date :period_start
      t.integer :estimated_minutes
      t.references :completed_by, foreign_key: { to_table: :users }
      t.datetime :completed_at
      t.references :released_by, foreign_key: { to_table: :users }
      t.datetime :released_at
    end
    add_index :tasks, [ :recurring_task_id, :period_start ], unique: true, where: "recurring_task_id IS NOT NULL"
    add_index :tasks, :completed_at

    # Every task must roll up to a workstream. Existing tasks go into a
    # "General" workstream per community for admins to re-file.
    execute <<~SQL
      INSERT INTO workstreams (community_id, name, description, workstream_type, status, priority, created_at, updated_at)
      SELECT id, 'General', 'Tasks from before workstreams existed. Re-file them as you go.',
             'permanent', 'active', 'important', NOW(), NOW()
      FROM communities
    SQL
    execute <<~SQL
      UPDATE tasks SET workstream_id = workstreams.id
      FROM workstreams
      WHERE workstreams.community_id = tasks.community_id AND workstreams.name = 'General'
    SQL
    # Completed tasks predate completion tracking; the best record we have.
    execute <<~SQL
      UPDATE tasks SET completed_at = updated_at, completed_by_id = COALESCE(assigned_to_user_id, user_id)
      WHERE status = 'completed'
    SQL

    change_column_null :tasks, :workstream_id, false
  end

  def down
    remove_index :tasks, [ :recurring_task_id, :period_start ]
    remove_index :tasks, :completed_at
    change_table :tasks, bulk: true do |t|
      t.remove_references :workstream, foreign_key: true
      t.remove_references :recurring_task, foreign_key: true
      t.remove :period_start, :estimated_minutes, :completed_at, :released_at
      t.remove_references :completed_by, foreign_key: { to_table: :users }
      t.remove_references :released_by, foreign_key: { to_table: :users }
    end
    execute "DELETE FROM workstreams WHERE name = 'General'"
  end
end
