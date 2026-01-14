class CloseRsvpsJob < ApplicationJob
  queue_as :default

  def perform
    email_delay = 0

    Community.find_each do |community|
      ActsAsTenant.with_tenant(community) do
        # Find meals past their RSVP deadline that are still open
        meals_to_close = Meal.where(rsvps_closed: false)
                            .where(status: "upcoming")
                            .where("rsvp_deadline <= ?", Time.current)

        meals_to_close.find_each do |meal|
          meal.close_rsvps!
          email_delay = MealNotificationService.rsvps_closed(meal, email_delay_start: email_delay)
          Rails.logger.info("CloseRsvpsJob: Closed RSVPs for meal #{meal.id} in #{community.name}, #{meal.total_attendees} attending")
        end
      end
    end
  end
end
