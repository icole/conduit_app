class RemoveDiscussions < ActiveRecord::Migration[8.1]
  # Removes the Discussions feature. This deletes data: discussion topics,
  # their comments and likes, the legacy topic_comments table, and their
  # audit versions. Production held 2 topics / 9 comments / 2 likes at the
  # time of writing.
  def up
    execute "DELETE FROM likes WHERE likeable_type = 'DiscussionTopic'"
    execute "DELETE FROM likes WHERE likeable_type = 'Comment' AND likeable_id IN (SELECT id FROM comments WHERE commentable_type = 'DiscussionTopic')"
    execute "DELETE FROM comments WHERE commentable_type = 'DiscussionTopic'"
    execute "DELETE FROM versions WHERE item_type = 'DiscussionTopic'"
    drop_table :topic_comments, if_exists: true
    drop_table :discussion_topics, if_exists: true
  end

  def down
    create_table :discussion_topics do |t|
      t.string :title, null: false
      t.text :description
      t.references :user, null: false, foreign_key: true
      t.datetime :last_activity_at
      t.references :community, null: false, foreign_key: true
      t.datetime :discarded_at
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :deleted_by, foreign_key: { to_table: :users }
      t.timestamps
      t.index :discarded_at
    end
    # topic_comments was a legacy table already migrated into comments; not recreated.
  end
end
