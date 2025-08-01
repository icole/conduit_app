# Configure SolidQueue recurring tasks
# This should be configured via Rails configuration, not by creating records directly

# For SolidQueue recurring tasks, they should be configured in application.rb or environment-specific files
# rather than creating database records directly

Rails.application.config.after_initialize do
  if Rails.env.production? || Rails.env.development?
    Rails.logger.info "SolidQueue recurring tasks configured via config/recurring.yml"

    # For now, let's just ensure the job can be run manually
    # You can trigger it with: ScheduledDriveSyncJob.perform_later
    Rails.logger.info "ScheduledDriveSyncJob is available for manual execution"
  end
end
