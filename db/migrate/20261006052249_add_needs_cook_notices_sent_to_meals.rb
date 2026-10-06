class AddNeedsCookNoticesSentToMeals < ActiveRecord::Migration[8.1]
  # How many "needs a cook" notices this meal has had (two weeks out, a week
  # out), so MealNeedsCookJob sends each once
  def change
    add_column :meals, :needs_cook_notices_sent, :integer, default: 0, null: false
  end
end
