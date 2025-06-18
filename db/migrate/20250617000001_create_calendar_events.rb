class CreateCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_events do |t|
      t.string :title, null: false
      t.text :description
      t.datetime :start_time, null: false
      t.datetime :end_time

      t.timestamps
    end
  end
end
