class DropMailingListTables < ActiveRecord::Migration[8.0]
  def change
    # Drop the join table first to avoid foreign key constraint issues
    drop_table :mailing_list_memberships do |t|
      t.references :mailing_list, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    # Drop the main mailing lists table
    drop_table :mailing_lists do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true
      t.string :mailgun_list_address
      t.timestamps
    end
  end
end
