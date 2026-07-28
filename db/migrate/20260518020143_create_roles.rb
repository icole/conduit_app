class CreateRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :roles do |t|
      t.references :community, null: false, foreign_key: true
      t.string :title, null: false
      t.text :duties
      t.text :description
      t.string :group
      t.string :role_type, null: false, default: "role"
      t.integer :term_length_months
      t.boolean :vacant, default: true, null: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :deleted_by, foreign_key: { to_table: :users }
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :roles, :group
    add_index :roles, :role_type
    add_index :roles, :vacant
    add_index :roles, :discarded_at
    add_index :roles, [ :community_id, :title ], unique: true
  end
end
