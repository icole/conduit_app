class CreateHouseholdDuesPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :household_dues_payments do |t|
      t.references :household, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :month, null: false
      t.boolean :paid, default: false, null: false

      t.timestamps
    end

    add_index :household_dues_payments, [ :household_id, :year, :month ],
              unique: true, name: "index_household_dues_on_household_year_month"
  end
end
