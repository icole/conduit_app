class MealMailer < ApplicationMailer
  def notification_email(user, title, body, url)
    @user = user
    @title = title
    @body = body
    @url = url

    mail(to: @user.email, subject: title)
  end

  def cook_confirmation(meal_cook)
    @meal_cook = meal_cook
    @meal = meal_cook.meal
    @user = meal_cook.user

    mail(to: @user.email, subject: "Cooking Confirmed: #{@meal.title}")
  end

  def rsvp_confirmation(rsvp)
    @rsvp = rsvp
    @meal = rsvp.meal
    @user = rsvp.user

    mail(to: @user.email, subject: "RSVP Confirmed: #{@meal.title}")
  end

  def meal_reminder(meal, user)
    @meal = meal
    @user = user

    mail(to: @user.email, subject: "Reminder: #{@meal.title} is tomorrow!")
  end

  def rsvp_deadline_warning(meal, user)
    @meal = meal
    @user = user

    mail(to: @user.email, subject: "RSVPs closing soon for #{@meal.title}")
  end

  def rsvps_closed_summary(meal, cook)
    @meal = meal
    @cook = cook
    @cooks = meal.meal_cooks.includes(:user)
    @attendees = meal.meal_rsvps.attending.includes(:user)
    @late_plates = meal.meal_rsvps.late_plate.includes(:user)
    @total_attending = meal.total_attendees
    @total_plates = meal.total_plates

    mail(to: @cook.email, subject: "Final headcount for #{@meal.title}: #{@total_attending} attending")
  end
end
