class CreateMealCooks < ActiveRecord::Migration[8.0]
  def change
    create_table :meal_cooks do |t|
      t.references :meal, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: 'helper'
      t.text :notes
      t.timestamps
    end

    add_index :meal_cooks, [ :meal_id, :user_id ], unique: true
    add_index :meal_cooks, :role
  end
end
