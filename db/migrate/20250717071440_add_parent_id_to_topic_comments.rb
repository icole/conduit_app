class AddParentIdToTopicComments < ActiveRecord::Migration[8.0]
  def change
    add_column :topic_comments, :parent_id, :integer
    add_index :topic_comments, :parent_id
  end
end
