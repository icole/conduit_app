class CreateMeals < ActiveRecord::Migration[8.0]
  def change
    create_table :meals do |t|
      t.references :meal_schedule, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.datetime :scheduled_at, null: false
      t.datetime :rsvp_deadline, null: false
      t.string :location
      t.string :status, null: false, default: 'upcoming'
      t.integer :max_attendees
      t.boolean :rsvps_closed, default: false, null: false
      t.text :cook_notes
      t.timestamps
    end

    add_index :meals, :scheduled_at
    add_index :meals, :status
    add_index :meals, :rsvp_deadline
    add_index :meals, [ :meal_schedule_id, :scheduled_at ]
  end
end
