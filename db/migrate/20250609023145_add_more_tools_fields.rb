class AddMoreToolsFields < ActiveRecord::Migration[8.0]
  def change
    add_column :tools, :location, :text
    add_column :tools, :checked_out_by, :string
    add_column :tools, :expected_return_by, :date
    add_column :tools, :status, :string, default: 'Available'
  end
end
