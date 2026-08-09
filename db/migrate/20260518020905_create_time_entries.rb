class CreateTimeEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :time_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :task, foreign_key: true
      t.references :role, foreign_key: true
      t.decimal :hours, precision: 5, scale: 2, null: false
      t.date :logged_on, null: false
      t.string :entry_type, null: false
      t.string :note
      t.timestamps
    end

    add_index :time_entries, :entry_type
    add_index :time_entries, :logged_on
    add_index :time_entries, [ :user_id, :logged_on ]
    add_index :time_entries, [ :role_id, :logged_on ]
  end
end
