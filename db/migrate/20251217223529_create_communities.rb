class CreateCommunities < ActiveRecord::Migration[8.0]
  def change
    create_table :communities do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :domain, null: false
      t.jsonb :settings, default: {}
      t.string :time_zone, default: "America/New_York"

      t.timestamps
    end

    add_index :communities, :domain, unique: true
    add_index :communities, :slug, unique: true
  end
end
