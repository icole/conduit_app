class RsvpDeadlineReminderJob < ApplicationJob
  queue_as :default

  def perform
    # Find meals with RSVPs closing in the next 2-2.5 hours
    closing_soon = Meal.rsvp_open
                      .where(rsvp_deadline: 2.hours.from_now..2.5.hours.from_now)
                      .includes(:cooks, :attendees)

    closing_soon.find_each do |meal|
      # Notify users who haven't RSVPed
      users_to_remind = User.where.not(id: meal.attendees.pluck(:id))
                           .where.not(id: meal.cooks.pluck(:id))

      users_to_remind.find_each do |user|
        MealNotificationService.rsvp_deadline_reminder(meal, user)
      end

      Rails.logger.info("RsvpDeadlineReminderJob: Sent #{users_to_remind.count} deadline reminders for meal #{meal.id}")
    end
  end
end
