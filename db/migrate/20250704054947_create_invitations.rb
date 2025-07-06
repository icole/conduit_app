class CreateInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :invitations do |t|
      t.string :token
      t.datetime :used_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_reference :invitations, :user, null: true, foreign_key: true
  end
end
