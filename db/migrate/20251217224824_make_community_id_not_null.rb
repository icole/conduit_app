class MakeCommunityIdNotNull < ActiveRecord::Migration[8.0]
  def up
    # Create default community if none exists
    execute <<-SQL
      INSERT INTO communities (name, slug, domain, created_at, updated_at)
      SELECT 'Crow Woods Cohousing', 'crow-woods', 'crowwoods.example.com', NOW(), NOW()
      WHERE NOT EXISTS (SELECT 1 FROM communities LIMIT 1);
    SQL

    # Get the default community ID
    default_community_id = execute("SELECT id FROM communities LIMIT 1")[0]["id"]

    # Update all records with NULL community_id to use the default
    [ :users, :posts, :tasks, :chores, :meals, :meal_schedules,
     :discussion_topics, :calendar_events, :documents, :decisions, :invitations ].each do |table|
      execute "UPDATE #{table} SET community_id = #{default_community_id} WHERE community_id IS NULL"
    end

    # Now add NOT NULL constraints
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

  def down
    # Remove NOT NULL constraints
    change_column_null :users, :community_id, true
    change_column_null :posts, :community_id, true
    change_column_null :tasks, :community_id, true
    change_column_null :chores, :community_id, true
    change_column_null :meals, :community_id, true
    change_column_null :meal_schedules, :community_id, true
    change_column_null :discussion_topics, :community_id, true
    change_column_null :calendar_events, :community_id, true
    change_column_null :documents, :community_id, true
    change_column_null :decisions, :community_id, true
    change_column_null :invitations, :community_id, true
  end
end
