class CreateChoreAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :chore_assignments do |t|
      t.references :chore, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :start_date
      t.date :end_date
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :chore_assignments, :active
    add_index :chore_assignments, [:chore_id, :active]
  end
end
