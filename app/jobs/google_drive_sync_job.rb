class GoogleDriveSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    folder_id = ENV["GOOGLE_DRIVE_FOLDER_ID"]

    return unless folder_id.present? && DriveShare.folder_shared_with_user?(folder_id, user)

    begin
      # Broadcast that sync is starting
      ActionCable.server.broadcast("drive_sync_#{user.id}", {
        type: "sync_started",
        message: "Refreshing files..."
      })

      # Fetch files from Google Drive
      drive_service = GoogleDriveApiService.from_service_account
      recent_files = drive_service.list_recent_files(folder_id)

      # Cache the results for 30 minutes
      cache_key = "drive_files_#{user.id}"
      Rails.cache.write(cache_key, recent_files, expires_in: 30.minutes)

      # Render the files list HTML server-side
      files_html = ApplicationController.render(
        partial: 'dashboard/files_list',
        locals: { files: recent_files[:files] }
      )

      # Broadcast success with rendered HTML
      ActionCable.server.broadcast("drive_sync_#{user.id}", {
        type: "sync_completed",
        html: files_html,
        status: recent_files[:status]
      })

    rescue StandardError => e
      Rails.logger.error("GoogleDriveSyncJob failed for user #{user.id}: #{e.message}")

      # Broadcast error
      ActionCable.server.broadcast("drive_sync_#{user.id}", {
        type: "sync_error",
        error: e.message
      })
    end
  end
end
