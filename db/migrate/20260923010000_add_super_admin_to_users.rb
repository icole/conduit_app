class AddSuperAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    # Operates across every community (approve, suspend, feature flags).
    # Set by hand in the console; never exposed in any UI.
    add_column :users, :super_admin, :boolean, null: false, default: false
  end
end
