class CreateCalendarShares < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_shares do |t|
      t.references :user, null: false, foreign_key: true
      t.string :calendar_id
      t.datetime :shared_at

      t.timestamps
    end
  end
end
