class CreateMailingLists < ActiveRecord::Migration[8.0]
  def change
    create_table :mailing_lists do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :mailing_lists, :name, unique: true
    add_index :mailing_lists, :active
  end
end
