class AddCommunityIdToModels < ActiveRecord::Migration[8.0]
  def change
    # Add community_id with NULL allowed initially for backfill
    add_reference :users, :community, foreign_key: true, null: true
    add_reference :posts, :community, foreign_key: true, null: true
    add_reference :tasks, :community, foreign_key: true, null: true
    add_reference :chores, :community, foreign_key: true, null: true
    add_reference :meals, :community, foreign_key: true, null: true
    add_reference :meal_schedules, :community, foreign_key: true, null: true
    add_reference :discussion_topics, :community, foreign_key: true, null: true
    add_reference :calendar_events, :community, foreign_key: true, null: true
    add_reference :documents, :community, foreign_key: true, null: true
    add_reference :decisions, :community, foreign_key: true, null: true
    add_reference :invitations, :community, foreign_key: true, null: true
  end
end
