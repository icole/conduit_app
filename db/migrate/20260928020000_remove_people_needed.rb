class RemovePeopleNeeded < ActiveRecord::Migration[8.1]
  # A shared task is just whoever's on it; the headcount from the first
  # version of shared tasks isn't used (ignored since the previous release).
  def change
    remove_column :tasks, :people_needed, :integer, null: false, default: 1
    remove_column :recurring_tasks, :people_needed, :integer, null: false, default: 1
  end
end
