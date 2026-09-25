class CreateWorkstreams < ActiveRecord::Migration[8.1]
  def change
    create_table :workstreams do |t|
      t.references :community, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      # permanent = Ongoing Operations, ad_hoc = One-Time Project
      t.string :workstream_type, null: false, default: "permanent"
      t.string :status, null: false, default: "active"
      t.string :priority, null: false, default: "important"
      t.references :owner, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :workstreams, [ :community_id, :status ]
  end
end
