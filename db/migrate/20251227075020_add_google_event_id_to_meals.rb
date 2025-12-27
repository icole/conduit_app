class AddGoogleEventIdToMeals < ActiveRecord::Migration[8.1]
  def change
    add_column :meals, :google_event_id, :string
    add_index :meals, :google_event_id, unique: true
  end
end
