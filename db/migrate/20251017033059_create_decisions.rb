class CreateDecisions < ActiveRecord::Migration[8.0]
  def change
    create_table :decisions do |t|
      t.string :title, null: false
      t.text :description
      t.date :decision_date
      t.references :calendar_event, null: true, foreign_key: true
      t.references :document, null: true, foreign_key: true

      t.timestamps
    end

    add_index :decisions, :decision_date
  end
end
