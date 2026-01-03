class AddMonthlyDuesAmountToCommunities < ActiveRecord::Migration[8.1]
  def change
    add_column :communities, :monthly_dues_amount, :decimal, precision: 10, scale: 2
  end
end
