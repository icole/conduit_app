class CreateRecurringTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :recurring_tasks do |t|
      t.references :community, null: false, foreign_key: true
      t.references :workstream, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :frequency, null: false, default: "weekly"
      # nil = inherit the workstream's priority
      t.string :priority
      t.integer :estimated_minutes, null: false
      t.references :default_responsible_user, foreign_key: { to_table: :users }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      # Anchors biweekly periods
      t.date :starts_on, null: false
      t.datetime :discarded_at
      t.timestamps
    end
    add_index :recurring_tasks, :discarded_at
  end
end
