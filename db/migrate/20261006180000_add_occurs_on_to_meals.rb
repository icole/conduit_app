# The schedule date a meal fills: the day its schedule made it for, or the day
# of the schedule's meal it replaces. Moving or deleting the meal keeps the
# date filled, so the schedule doesn't make that week's meal again.
class AddOccursOnToMeals < ActiveRecord::Migration[8.0]
  def up
    add_column :meals, :occurs_on, :date

    # Meals a schedule already made fill the date they're on, in the zone the
    # schedule generates in
    zone = connection.quote(Time.zone.tzinfo.name)
    execute <<~SQL
      UPDATE meals SET occurs_on = (scheduled_at AT TIME ZONE 'UTC' AT TIME ZONE #{zone})::date
      WHERE meal_schedule_id IS NOT NULL
    SQL

    add_index :meals, [ :meal_schedule_id, :occurs_on ], unique: true,
      where: "discarded_at IS NULL AND occurs_on IS NOT NULL", name: "index_meals_one_live_meal_per_schedule_date"
  end

  def down
    remove_index :meals, name: "index_meals_one_live_meal_per_schedule_date"
    remove_column :meals, :occurs_on
  end
end
