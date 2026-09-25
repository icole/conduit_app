class CreateWorkstreamOwners < ActiveRecord::Migration[8.1]
  # A workstream can have several owners (e.g. a project run by two people).
  def up
    create_table :workstream_owners do |t|
      t.references :community, null: false, foreign_key: true
      t.references :workstream, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :workstream_owners, [ :workstream_id, :user_id ], unique: true

    execute <<~SQL
      INSERT INTO workstream_owners (community_id, workstream_id, user_id, created_at, updated_at)
      SELECT community_id, id, owner_id, NOW(), NOW() FROM workstreams WHERE owner_id IS NOT NULL
    SQL

    remove_reference :workstreams, :owner, foreign_key: { to_table: :users }
  end

  def down
    add_reference :workstreams, :owner, foreign_key: { to_table: :users }
    execute <<~SQL
      UPDATE workstreams SET owner_id = (
        SELECT user_id FROM workstream_owners
        WHERE workstream_owners.workstream_id = workstreams.id ORDER BY id LIMIT 1
      )
    SQL
    drop_table :workstream_owners
  end
end
