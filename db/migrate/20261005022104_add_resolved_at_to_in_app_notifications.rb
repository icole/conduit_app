class AddResolvedAtToInAppNotifications < ActiveRecord::Migration[8.1]
  # When the thing a notification asked of the member was dealt with (CON-72),
  # apart from read_at, when they saw it
  def change
    add_column :in_app_notifications, :resolved_at, :datetime
    add_index :in_app_notifications, [ :user_id, :resolved_at ]
  end
end
