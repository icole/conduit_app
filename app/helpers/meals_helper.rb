module MealsHelper
  # Returns users who are not already cooks for this meal
  def available_users_for_cook(meal)
    cook_user_ids = meal.meal_cooks.pluck(:user_id)
    User.where.not(id: cook_user_ids).order(:name)
  end

  # Returns users who are not already RSVPed and not cooks for this meal
  def available_users_for_rsvp(meal)
    rsvp_user_ids = meal.meal_rsvps.pluck(:user_id)
    cook_user_ids = meal.meal_cooks.pluck(:user_id)
    excluded_ids = (rsvp_user_ids + cook_user_ids).uniq
    User.where.not(id: excluded_ids).order(:name)
  end
end
