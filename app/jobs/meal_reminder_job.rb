class MealReminderJob < ApplicationJob
  queue_as :default

  def perform
    batch_service = BatchEmailService.new

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
            MealNotificationService.meal_reminder(meal, user, batch_service: batch_service)
          end

          Rails.logger.info("MealReminderJob: Queued #{users_to_remind.count} reminders for meal #{meal.id} in #{community.name}")
        end
      end
    end

    # Send all emails in batches of 100
    total_emails = batch_service.size
    responses = batch_service.deliver_all
    Rails.logger.info("MealReminderJob: Sent #{total_emails} emails in #{responses.size} batch(es)")
  end
end
