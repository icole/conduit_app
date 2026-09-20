class RemovePosts < ActiveRecord::Migration[8.1]
  # Removes the Posts feature. Nothing rendered posts any more (the dashboard
  # feed was replaced by the timeline). Deletes data: posts and their comments,
  # likes and audit versions; also drops the legacy comments.post_id column.
  def up
    execute "DELETE FROM likes WHERE likeable_type = 'Post'"
    execute "DELETE FROM likes WHERE likeable_type = 'Comment' AND likeable_id IN (SELECT id FROM comments WHERE commentable_type = 'Post')"
    execute "DELETE FROM comments WHERE commentable_type = 'Post'"
    execute "DELETE FROM versions WHERE item_type = 'Post'"
    remove_reference :comments, :post, foreign_key: true, index: true, if_exists: true
    drop_table :posts, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Posts were removed along with their data"
  end
end
