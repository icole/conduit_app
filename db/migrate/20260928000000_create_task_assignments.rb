class CreateTaskAssignments < ActiveRecord::Migration[8.1]
  # A task can need more than one person (meeting facilitation takes two), so
  # who's doing it moves from tasks.assigned_to_user_id to task_assignments,
  # and a recurring task's default person to recurring_task_responsibles.
  #
  # The old columns stay for now, ignored by the models, so the release that's
  # still running during a deploy doesn't break. A later migration drops them.
  def up
    create_table :task_assignments do |t|
      t.references :community, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      # Set when this person took a spot someone released
      t.references :covering_for, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :task_assignments, [ :task_id, :user_id ], unique: true

    create_table :recurring_task_responsibles do |t|
      t.references :community, null: false, foreign_key: true
      t.references :recurring_task, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :recurring_task_responsibles, [ :recurring_task_id, :user_id ], unique: true

    add_column :tasks, :people_needed, :integer, null: false, default: 1
    add_column :recurring_tasks, :people_needed, :integer, null: false, default: 1

    execute <<~SQL
      INSERT INTO task_assignments (community_id, task_id, user_id, covering_for_id, created_at, updated_at)
      SELECT community_id, id, assigned_to_user_id,
             CASE WHEN released_by_id IS NOT NULL AND released_by_id <> assigned_to_user_id THEN released_by_id END,
             NOW(), NOW()
      FROM tasks WHERE assigned_to_user_id IS NOT NULL
    SQL

    execute <<~SQL
      INSERT INTO recurring_task_responsibles (community_id, recurring_task_id, user_id, created_at, updated_at)
      SELECT community_id, id, default_responsible_user_id, NOW(), NOW()
      FROM recurring_tasks WHERE default_responsible_user_id IS NOT NULL
    SQL
  end

  def down
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
    remove_column :recurring_tasks, :people_needed
    remove_column :tasks, :people_needed
    drop_table :recurring_task_responsibles
    drop_table :task_assignments
  end
end
