class CreateEmailLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :email_logs do |t|
      t.references :community, null: false, foreign_key: true
      t.string :to, null: false
      t.string :from
      t.string :subject
      t.string :mailer_class
      t.string :mailer_action
      t.string :status, default: "pending", null: false
      t.text :error_message
      t.datetime :sent_at
      t.timestamps
    end

    add_index :email_logs, [ :community_id, :created_at ]
    add_index :email_logs, :status
  end
end
