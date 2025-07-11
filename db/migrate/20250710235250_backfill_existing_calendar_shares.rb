class BackfillExistingCalendarShares < ActiveRecord::Migration[8.0]
  def up
    # Get all users
    User.find_each do |user|
      # Skip if the user doesn't have an email (which would be needed for calendar sharing)
      next if user.email.blank?

      # Create a calendar share record for the default calendar
      calendar_id = ENV["GOOGLE_CALENDAR_ID"]
      next if calendar_id.blank?

      # Only create if it doesn't exist already
      unless CalendarShare.exists?(user_id: user.id, calendar_id: calendar_id)
        CalendarShare.create!(
          user_id: user.id,
          calendar_id: calendar_id,
          shared_at: 1.day.ago # Assume it was shared in the past
        )
        puts "Created calendar share record for user #{user.id} (#{user.email})"
      end
    end
  end

  def down
    # This migration is not reversible
    raise ActiveRecord::IrreversibleMigration
  end
end
