# frozen_string_literal: true

class CreateDriveShares < ActiveRecord::Migration[7.0]
  def change
    create_table :drive_shares do |t|
      t.references :user, null: false, foreign_key: true
      t.string :folder_id, null: false
      t.string :folder_name
      t.string :permission_id
      t.string :role, default: "reader"
      t.datetime :shared_at, null: false

      t.timestamps
    end

    # Add index for quick lookups
    add_index :drive_shares, [ :folder_id, :user_id ], unique: true
  end
end
