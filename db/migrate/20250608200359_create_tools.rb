class CreateTools < ActiveRecord::Migration[8.0]
  def change
    create_table :tools, id: :uuid do |t|
      t.string :title
      t.string :description
      t.boolean :available
      t.timestamps
    end
  end
end
