class CreateMealSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :meal_schedules do |t|
      t.string :name, null: false
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.time :end_time
      t.string :location
      t.integer :max_cooks, default: 2
      t.integer :rsvp_deadline_hours, default: 24
      t.boolean :active, default: true, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :meal_schedules, :day_of_week
    add_index :meal_schedules, :active
  end
end
