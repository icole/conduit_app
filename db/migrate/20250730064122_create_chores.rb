class CreateChores < ActiveRecord::Migration[8.0]
  def change
    create_table :chores do |t|
      t.string :name, null: false
      t.text :description
      t.string :frequency, null: false # daily, weekly, biweekly, monthly, custom
      t.jsonb :frequency_details, default: {} # e.g., { day_of_week: 3 } for Wednesday
      t.string :status, null: false, default: 'proposed' # proposed, active, archived
      t.references :proposed_by, null: false, foreign_key: { to_table: :users }
      t.date :next_due_date

      t.timestamps
    end

    add_index :chores, :status
    add_index :chores, :next_due_date
  end
end
