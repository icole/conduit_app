class AddEmailVerificationToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :email_verified_at, :datetime
    add_column :users, :email_verification_sent_at, :datetime
    # Everyone who exists today was invited by an admin and has been using
    # the app; treat them as verified rather than locking them out of chat.
    execute "UPDATE users SET email_verified_at = created_at"
  end

  def down
    remove_column :users, :email_verification_sent_at
    remove_column :users, :email_verified_at
  end
end
