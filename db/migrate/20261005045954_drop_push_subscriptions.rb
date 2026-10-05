# Browser push was never wired up: no client subscribed and production had no
# rows. Phones get pushes through the apps instead (CON-72).
class DropPushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    drop_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.text :endpoint, null: false
      t.string :p256dh_key, null: false
      t.string :auth_key, null: false
      t.timestamps
      t.index [ :user_id, :endpoint ], unique: true
    end
  end
end
