class MakeCommunityIdNotNull < ActiveRecord::Migration[8.0]
  def change
    # Add NOT NULL constraints to all community_id columns
    # This should only be run after all data has been backfilled
    change_column_null :users, :community_id, false
    change_column_null :posts, :community_id, false
    change_column_null :tasks, :community_id, false
    change_column_null :chores, :community_id, false
    change_column_null :meals, :community_id, false
    change_column_null :meal_schedules, :community_id, false
    change_column_null :discussion_topics, :community_id, false
    change_column_null :calendar_events, :community_id, false
    change_column_null :documents, :community_id, false
    change_column_null :decisions, :community_id, false
    change_column_null :invitations, :community_id, false
  end
end
