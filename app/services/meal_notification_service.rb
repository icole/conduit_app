class MealNotificationService
  class << self
    # Resend API rate limit: 2 requests/second on free tier
    # We use 1 request/second to be safe and allow headroom (used as fallback)
    EMAIL_DELAY_SECONDS = 1

    def meal_reminder(meal, user, email_delay: 0, batch_service: nil)
      title = "Meal Tomorrow: #{meal.title}"
      body = "#{meal.title} is tomorrow at #{meal.time_display}. RSVP if you're coming!"
      url = meal_url(meal)

      send_all_channels(
        user: user,
        title: title,
        body: body,
        url: url,
        notification_type: InAppNotification::TYPES[:meal_reminder],
        notifiable: meal,
        mailer: -> { MealMailer.meal_reminder(meal, user) },
        email_delay: email_delay,
        batch_service: batch_service
      )
    end

    def rsvp_deadline_reminder(meal, user, email_delay: 0, batch_service: nil)
      title = "RSVPs Closing Soon!"
      body = "RSVPs for #{meal.title} close in about 2 hours. Don't forget to respond!"
      url = meal_url(meal)

      send_all_channels(
        user: user,
        title: title,
        body: body,
        url: url,
        notification_type: InAppNotification::TYPES[:rsvp_deadline],
        notifiable: meal,
        mailer: -> { MealMailer.rsvp_deadline_warning(meal, user) },
        email_delay: email_delay,
        batch_service: batch_service
      )
    end

    def cook_assigned(meal_cook)
      meal = meal_cook.meal
      user = meal_cook.user
      role_name = meal_cook.head_cook? ? "head cook" : "helper"

      title = "Cooking Assignment Confirmed"
      body = "You're signed up as #{role_name} for #{meal.title} on #{meal.scheduled_at.strftime('%b %d')}."
      url = meal_url(meal)

      send_all_channels(
        user: user,
        title: title,
        body: body,
        url: url,
        notification_type: InAppNotification::TYPES[:cook_assigned],
        notifiable: meal,
        skip_email: true  # TODO: Re-enable cook confirmation email
      )

      # Notify other cooks about new team member
      notify_other_cooks(meal, user, role_name)
    end

    def rsvps_closed(meal)
      title = "RSVPs Closed: #{meal.title}"
      body = "RSVPs are now closed. #{meal.total_attendees} people attending."
      url = meal_url(meal)

      # Low volume (1-2 cooks per meal), no batching needed
      meal.cooks.each do |cook|
        send_all_channels(
          user: cook,
          title: title,
          body: body,
          url: url,
          notification_type: InAppNotification::TYPES[:rsvps_closed],
          notifiable: meal,
          mailer: -> { MealMailer.rsvps_closed_summary(meal, cook) }
        )
      end
    end

    private

    def send_all_channels(user:, title:, body:, url:, notification_type:, notifiable:, mailer: nil, skip_email: false, email_delay: 0, batch_service: nil)
      # 1. Create in-app notification
      user.in_app_notifications.create!(
        title: title,
        body: body,
        notification_type: notification_type,
        notifiable: notifiable,
        action_url: url
      )

      # 2. Send push notification
      PushNotificationService.send(
        user: user,
        title: title,
        body: body,
        url: url,
        tag: "meal-#{notifiable.id}"
      )

      # 3. Send email notification (use custom mailer if provided, otherwise generic)
      unless skip_email
        email = mailer&.call || MealMailer.notification_email(user, title, body, url)

        if batch_service
          # Add to batch for bulk sending (avoids rate limits)
          batch_service.add(email)
        elsif email_delay > 0
          # Fallback: stagger individual emails to respect rate limits
          email.deliver_later(wait: email_delay.seconds)
        else
          email.deliver_later
        end
      end
    rescue StandardError => e
      Rails.logger.error("Failed to send notification to user #{user.id}: #{e.message}")
    end

    def notify_other_cooks(meal, new_cook, role_name)
      meal.cooks.where.not(id: new_cook.id).each do |other_cook|
        other_cook.in_app_notifications.create!(
          title: "New Cook Joined",
          body: "#{new_cook.name} joined as #{role_name} for #{meal.title}.",
          notification_type: InAppNotification::TYPES[:cook_assigned],
          notifiable: meal,
          action_url: meal_url(meal)
        )
      end
    end

    def meal_url(meal)
      Rails.application.routes.url_helpers.meal_path(meal)
    end
  end
end
