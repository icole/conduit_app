class ChangeUserEmailUniqueness < ActiveRecord::Migration[8.0]
  def change
    # Remove old global unique index on email
    remove_index :users, :email

    # Add composite unique index for email within community
    add_index :users, [ :community_id, :email ], unique: true

    # Update OAuth uniqueness to be scoped to community
    remove_index :users, [ :provider, :uid ]
    add_index :users, [ :community_id, :provider, :uid ], unique: true
  end
end
