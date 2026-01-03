class AddHouseholdIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :household, null: true, foreign_key: true
  end
end
