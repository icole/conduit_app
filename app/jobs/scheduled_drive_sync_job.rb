class ScheduledDriveSyncJob < ApplicationJob
  queue_as :default

  def perform
    Community.find_each do |community|
      ActsAsTenant.with_tenant(community) do
        folder_id = community.google_drive_folder_id
        next unless folder_id.present?

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
  end
end
