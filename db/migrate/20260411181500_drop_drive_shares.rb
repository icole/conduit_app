class DropDriveShares < ActiveRecord::Migration[8.1]
  def up
    drop_table :drive_shares
  end

  def down
    create_table :drive_shares do |t|
      t.references :user, null: false, foreign_key: true
      t.string :folder_id, null: false
      t.string :folder_name
      t.string :permission_id
      t.string :role, default: "reader"
      t.datetime :shared_at
      t.timestamps
    end

    add_index :drive_shares, [ :folder_id, :user_id ], unique: true
  end
end
