class CreateActionPushNativeDevices < ActiveRecord::Migration[8.1]
  # The action_push_native gem's device table: the phones (APNs / FCM tokens)
  # we can send push notifications to. db/schema.rb already listed this table
  # without a migration (CON-69), so create it only where it's missing.
  def change
    create_table :action_push_native_devices, if_not_exists: true do |t|
      t.string :name
      t.string :platform, null: false
      t.string :token, null: false
      t.belongs_to :owner, polymorphic: true

      t.timestamps
    end
    add_index :action_push_native_devices, [ :token, :platform ], unique: true, if_not_exists: true
  end
end
