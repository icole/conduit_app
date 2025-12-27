class AddSoftDeleteAndUserTrackingToContentModels < ActiveRecord::Migration[8.1]
  def change
    tables = %i[
      posts
      comments
      tasks
      documents
      decisions
      meals
      chores
      calendar_events
      discussion_topics
    ]

    tables.each do |table|
      add_column table, :discarded_at, :datetime
      add_column table, :created_by_id, :bigint
      add_column table, :deleted_by_id, :bigint

      add_index table, :discarded_at
      add_index table, :created_by_id
      add_index table, :deleted_by_id

      add_foreign_key table, :users, column: :created_by_id
      add_foreign_key table, :users, column: :deleted_by_id
    end
  end
end
