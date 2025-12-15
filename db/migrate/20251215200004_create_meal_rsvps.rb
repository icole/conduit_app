class CreateMealRsvps < ActiveRecord::Migration[8.0]
  def change
    create_table :meal_rsvps do |t|
      t.references :meal, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'attending'
      t.integer :guests_count, default: 0, null: false
      t.text :notes
      t.timestamps
    end

    add_index :meal_rsvps, [ :meal_id, :user_id ], unique: true
    add_index :meal_rsvps, :status
  end
end
