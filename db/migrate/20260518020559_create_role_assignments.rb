class CreateRoleAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :role_assignments do |t|
      t.references :role, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :assignment_type, null: false, default: "holder"
      t.date :starts_at, null: false
      t.date :ends_at
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :role_assignments, :assignment_type
    add_index :role_assignments, :active
    add_index :role_assignments, :ends_at
    add_index :role_assignments, [ :role_id, :user_id, :active ], name: "idx_role_assignments_unique_active",
              unique: true, where: "active = true AND assignment_type = 'holder'"
  end
end
