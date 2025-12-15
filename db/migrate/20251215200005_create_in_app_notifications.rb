class CreateInAppNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :in_app_notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body
      t.string :notification_type, null: false
      t.string :notifiable_type
      t.bigint :notifiable_id
      t.string :action_url
      t.boolean :read, default: false, null: false
      t.datetime :read_at
      t.timestamps
    end

    add_index :in_app_notifications, [ :user_id, :read ]
    add_index :in_app_notifications, [ :notifiable_type, :notifiable_id ]
    add_index :in_app_notifications, :notification_type
  end
end
