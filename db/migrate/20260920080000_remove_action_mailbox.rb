class RemoveActionMailbox < ActiveRecord::Migration[8.1]
  # ActionMailbox was installed but never received mail (ingress disabled).
  # The engine mount and the empty ApplicationMailbox are gone too.
  def up
    drop_table :action_mailbox_inbound_emails, if_exists: true
  end

  def down
    create_table :action_mailbox_inbound_emails do |t|
      t.integer :status, default: 0, null: false
      t.string :message_id, null: false
      t.string :message_checksum, null: false
      t.timestamps
      t.index [ :message_id, :message_checksum ], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
    end
  end
end
