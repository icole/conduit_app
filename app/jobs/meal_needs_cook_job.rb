# Meals are posted weeks ahead so people can sign up to cook first. One that
# still has no head cook two weeks out, and again a week out, goes to everyone
# in the community: in the bell (it needs someone, and clears for everyone
# once a head cook signs up) and to their phones.
#
# Runs once a day. Each meal counts the notices it's had, so none repeats,
# and a meal first posted inside the week gets only the one-week notice.
class MealNeedsCookJob < ApplicationJob
  queue_as :default

  # Days before the meal, in the community's time zone
  NOTICES = [ 14, 7 ].freeze

  def perform
    Community.active.find_each do |community|
      now = Time.current.in_time_zone(community.time_zone)
      ActsAsTenant.with_tenant(community) { nudge(now) }
    end
  end

  private

  def nudge(now)
    meals = Meal.upcoming.includes(:meal_cooks).where(scheduled_at: ..(now.end_of_day + NOTICES.max.days))
    meals.each do |meal|
      next unless meal.needs_head_cook?

      days_away = (meal.scheduled_at.in_time_zone(now.time_zone).to_date - now.to_date).to_i
      due = NOTICES.count { |days| days_away <= days }
      next if due <= meal.needs_cook_notices_sent

      User.find_each { |user| MealNotificationService.needs_cook(meal, user) }
      meal.update_columns(needs_cook_notices_sent: due)
    end
  end
end
