class CreateMailingListMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :mailing_list_memberships do |t|
      t.references :mailing_list, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :mailing_list_memberships, [ :mailing_list_id, :user_id ], unique: true, name: 'index_memberships_on_list_and_user'
  end
end
