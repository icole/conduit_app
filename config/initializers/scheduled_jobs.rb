# Schedule recurring jobs
Rails.application.config.after_initialize do
  # Schedule the drive sync job to run every hour
  # This will proactively refresh the cache for all users
  if Rails.env.production? || Rails.env.development?
    begin
      # Clear any existing scheduled jobs with the same name to avoid duplicates
      SolidQueue::RecurringTask.where(key: "scheduled_drive_sync").destroy_all

      # Schedule the job to run every hour
      SolidQueue::RecurringTask.create!(
        key: "scheduled_drive_sync",
        class_name: "ScheduledDriveSyncJob",
        cron: "0 * * * *", # Every hour at minute 0
        queue_name: "default"
      )

      Rails.logger.info "Scheduled ScheduledDriveSyncJob to run every hour"
    rescue => e
      Rails.logger.error "Failed to schedule ScheduledDriveSyncJob: #{e.message}"
    end
  end
end
