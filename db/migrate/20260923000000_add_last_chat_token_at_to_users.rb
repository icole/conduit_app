class AddLastChatTokenAtToUsers < ActiveRecord::Migration[8.1]
  def change
    # When we last issued this user a Stream token: our proxy for Stream's
    # monthly-active-user count, which is what the plan is billed on.
    add_column :users, :last_chat_token_at, :datetime
    add_index :users, :last_chat_token_at
  end
end
