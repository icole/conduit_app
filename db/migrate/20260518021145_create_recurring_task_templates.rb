class CreateRecurringTaskTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :recurring_task_templates do |t|
      t.references :role, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :frequency, null: false
      t.boolean :auto_assign_to_holder, default: true, null: false
      t.date :last_generated_at
      t.timestamps
    end

    add_index :recurring_task_templates, :frequency
  end
end
