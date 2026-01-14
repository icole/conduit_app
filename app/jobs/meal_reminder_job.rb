class MealReminderJob < ApplicationJob
  queue_as :default

  def perform
    email_delay = 0

    Community.find_each do |community|
      ActsAsTenant.with_tenant(community) do
        # Find meals happening in the next 24-26 hours (to avoid double-reminders)
        upcoming_meals = Meal.upcoming
                            .where(scheduled_at: 24.hours.from_now..26.hours.from_now)
                            .includes(:cooks, :attendees)

        upcoming_meals.find_each do |meal|
          # Get users who haven't RSVPed or signed up to cook
          users_to_remind = User.where.not(id: meal.attendees.pluck(:id))
                               .where.not(id: meal.cooks.pluck(:id))

          users_to_remind.find_each do |user|
            MealNotificationService.meal_reminder(meal, user, email_delay: email_delay)
            email_delay += MealNotificationService::EMAIL_DELAY_SECONDS
          end

          Rails.logger.info("MealReminderJob: Sent #{users_to_remind.count} reminders for meal #{meal.id} in #{community.name}")
        end
      end
    end
  end
end
