class AddLastActivityAtToDiscussionTopics < ActiveRecord::Migration[8.0]
  def up
    add_column :discussion_topics, :last_activity_at, :datetime

    # Set initial values - use the maximum of topic creation time or latest comment time
    execute <<-SQL
      UPDATE discussion_topics
      SET last_activity_at =#{' '}
        COALESCE(
          (SELECT MAX(created_at) FROM topic_comments WHERE discussion_topic_id = discussion_topics.id),
          discussion_topics.created_at
        )
    SQL
  end

  def down
    remove_column :discussion_topics, :last_activity_at
  end
end
