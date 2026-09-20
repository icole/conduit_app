class AddTokenVersionToUsers < ActiveRecord::Migration[8.1]
  def change
    # Bumped to invalidate every mobile JWT issued to the user (logout,
    # password change, suspension). Embedded in the token and compared on verify.
    add_column :users, :token_version, :integer, null: false, default: 0
  end
end
