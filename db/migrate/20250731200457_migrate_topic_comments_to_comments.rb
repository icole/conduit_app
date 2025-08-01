class MigrateTopicCommentsToComments < ActiveRecord::Migration[8.0]
  def up
    # Migrate existing TopicComments to Comments table
    say "Migrating TopicComments to Comments table..."

    # Create a mapping table for old TopicComment IDs to new Comment IDs
    id_mapping = {}

    # First, migrate top-level comments (parent_id is null)
    TopicComment.where(parent_id: nil).find_each do |tc|
      new_comment = Comment.create!(
        content: tc.content,
        user_id: tc.user_id,
        commentable_type: 'DiscussionTopic',
        commentable_id: tc.discussion_topic_id,
        parent_id: nil,
        created_at: tc.created_at,
        updated_at: tc.updated_at
      )
      id_mapping[tc.id] = new_comment.id
    end

    # Then migrate replies, mapping parent_id to new Comment IDs
    TopicComment.where.not(parent_id: nil).find_each do |tc|
      new_parent_id = id_mapping[tc.parent_id]
      next unless new_parent_id # Skip if parent wasn't migrated

      new_comment = Comment.create!(
        content: tc.content,
        user_id: tc.user_id,
        commentable_type: 'DiscussionTopic',
        commentable_id: tc.discussion_topic_id,
        parent_id: new_parent_id,
        created_at: tc.created_at,
        updated_at: tc.updated_at
      )
      id_mapping[tc.id] = new_comment.id
    end

    say "Migrated #{id_mapping.count} topic comments to comments table"
  end

  def down
    # Remove migrated TopicComments from Comments table
    Comment.where(commentable_type: 'DiscussionTopic').delete_all
    say "Removed migrated topic comments from comments table"
  end
end
