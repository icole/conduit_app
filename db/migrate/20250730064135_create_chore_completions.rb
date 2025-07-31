class CreateChoreCompletions < ActiveRecord::Migration[8.0]
  def change
    create_table :chore_completions do |t|
      t.references :chore, null: false, foreign_key: true
      t.references :completed_by, null: false, foreign_key: { to_table: :users }
      t.datetime :completed_at, null: false
      t.text :notes

      t.timestamps
    end

    add_index :chore_completions, :completed_at
    add_index :chore_completions, [:chore_id, :completed_at]
  end
end
