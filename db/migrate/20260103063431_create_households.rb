class CreateHouseholds < ActiveRecord::Migration[8.1]
  def change
    create_table :households do |t|
      t.references :community, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :households, [ :community_id, :name ], unique: true
  end
end
