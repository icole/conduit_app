class RsvpDeadlineReminderJob < ApplicationJob
  queue_as :default

  def perform
    batch_service = BatchEmailService.new

    Community.find_each do |community|
      ActsAsTenant.with_tenant(community) do
        # Find meals with RSVPs closing in the next 2-2.5 hours
        closing_soon = Meal.rsvp_open
                          .where(rsvp_deadline: 2.hours.from_now..2.5.hours.from_now)
                          .includes(:cooks, :attendees)

        closing_soon.find_each do |meal|
          # Notify users who haven't RSVPed
          users_to_remind = User.where.not(id: meal.attendees.pluck(:id))
                               .where.not(id: meal.cooks.pluck(:id))

          users_to_remind.find_each do |user|
            MealNotificationService.rsvp_deadline_reminder(meal, user, batch_service: batch_service)
          end

          Rails.logger.info("RsvpDeadlineReminderJob: Queued #{users_to_remind.count} deadline reminders for meal #{meal.id} in #{community.name}")
        end
      end
    end

    # Send all emails in batches of 100
    total_emails = batch_service.size
    responses = batch_service.deliver_all
    Rails.logger.info("RsvpDeadlineReminderJob: Sent #{total_emails} emails in #{responses.size} batch(es)")
  end
end
