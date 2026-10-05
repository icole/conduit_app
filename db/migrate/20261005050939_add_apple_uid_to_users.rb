class AddAppleUidToUsers < ActiveRecord::Migration[8.1]
  # Sign in with Apple's stable user ID (the token's sub), kept apart from
  # Google's provider/uid so a member can use both (CON-64)
  def change
    add_column :users, :apple_uid, :string
    add_index :users, [ :community_id, :apple_uid ], unique: true, where: "apple_uid IS NOT NULL"
  end
end
