class AddStatusToCommunities < ActiveRecord::Migration[8.1]
  def up
    # New (self-created) communities start pending and are approved by hand;
    # everything that exists today was created by us and is live.
    add_column :communities, :status, :string, null: false, default: "pending"
    add_index :communities, :status
    execute "UPDATE communities SET status = 'active'"
  end

  def down
    remove_index :communities, :status
    remove_column :communities, :status
  end
end
