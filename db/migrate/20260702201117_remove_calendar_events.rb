class RemoveCalendarEvents < ActiveRecord::Migration[8.1]
  def up
    remove_reference :decisions, :calendar_event, foreign_key: true, if_exists: true
    drop_table :calendar_events_documents, if_exists: true
    drop_table :calendar_events, if_exists: true
  end

  def down
    create_table :calendar_events do |t|
      t.string :title, null: false
      t.text :description
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.string :google_event_id
      t.string :location
      t.references :community, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :deleted_by, foreign_key: { to_table: :users }
      t.datetime :discarded_at
      t.timestamps
      t.index :discarded_at
    end

    create_table :calendar_events_documents do |t|
      t.references :calendar_event, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.timestamps
      t.index [ :calendar_event_id, :document_id ], unique: true, name: "index_calendar_events_documents_uniqueness"
    end

    add_reference :decisions, :calendar_event, foreign_key: true
  end
end
