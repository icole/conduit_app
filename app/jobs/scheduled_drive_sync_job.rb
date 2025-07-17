class ScheduledDriveSyncJob < ApplicationJob
  queue_as :default

  def perform
    folder_id = ENV["GOOGLE_DRIVE_FOLDER_ID"]
    return unless folder_id.present?

    # Find all users who have access to the drive folder
    users_with_access = User.joins(:drive_shares)
                           .where(drive_shares: { folder_id: folder_id })
                           .distinct

    # Refresh cache for each user
    users_with_access.find_each do |user|
      GoogleDriveSyncJob.perform_later(user.id)
    end
  end
end
