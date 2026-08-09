class CreateWorkloadSentiments < ActiveRecord::Migration[8.0]
  def change
    create_table :workload_sentiments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.string :sentiment, null: false
      t.date :month, null: false
      t.timestamps
    end

    add_index :workload_sentiments, [ :user_id, :role_id, :month ], unique: true, name: "idx_workload_sentiments_unique"
  end
end
