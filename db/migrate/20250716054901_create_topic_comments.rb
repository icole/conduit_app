class CreateTopicComments < ActiveRecord::Migration[8.0]
  def change
    create_table :topic_comments do |t|
      t.text :content
      t.references :user, null: false, foreign_key: true
      t.references :discussion_topic, null: false, foreign_key: true

      t.timestamps
    end
  end
end
