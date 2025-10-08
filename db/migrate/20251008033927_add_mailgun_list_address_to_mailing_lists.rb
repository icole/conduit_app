class AddMailgunListAddressToMailingLists < ActiveRecord::Migration[8.0]
  def change
    add_column :mailing_lists, :mailgun_list_address, :string
    add_index :mailing_lists, :mailgun_list_address, unique: true
  end
end
