class AddRestrictedAccessToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :restricted_access, :boolean, default: false, null: false
  end
end
