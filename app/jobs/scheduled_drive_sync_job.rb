class ScheduledDriveSyncJob < ApplicationJob
  queue_as :default

  def perform
    Community.find_each do |community|
      next unless community.google_drive_folder_id.present?

      Rails.logger.info("[ScheduledDriveSync] Importing documents for #{community.name}")
      result = GoogleDriveNativeImportService.new(community).import!
      Rails.logger.info("[ScheduledDriveSync] #{community.name}: #{result[:message]}")
    end
  end
end
