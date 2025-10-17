class CreateCalendarEventsDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_events_documents do |t|
      t.references :calendar_event, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true

      t.timestamps
    end

    add_index :calendar_events_documents, [ :calendar_event_id, :document_id ],
              unique: true, name: "index_calendar_events_documents_uniqueness"
  end
end
