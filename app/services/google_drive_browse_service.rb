# frozen_string_literal: true

# Service for browsing Google Drive contents live (no DB sync).
# Wraps GoogleDriveApiService to list folders and files in a community's Drive folder.
class GoogleDriveBrowseService
  def initialize(community)
    @community = community
  end

  def configured?
    @community.google_drive_folder_id.present?
  end

  # List recent files across all subfolders in the community's Drive.
  # Returns { files: [...], error: nil }
  def recent_files(max_results: 5)
    folder_id = @community.google_drive_folder_id
    api = GoogleDriveApiService.from_service_account
    result = api.list_recent_files(folder_id, max_results: max_results)
    { files: result[:files] || [], error: nil }
  rescue StandardError => e
    Rails.logger.error("GoogleDriveBrowseService recent_files error: #{e.message}")
    { files: [], error: e.message }
  end

  # List folders and files in a Drive folder.
  # Uses the community's root Drive folder when no parent_id given.
  # Returns { folders: [...], files: [...], error: nil }
  def list_contents(parent_id = nil)
    parent_id ||= @community.google_drive_folder_id

    api = GoogleDriveApiService.from_service_account

    folders_result = api.list_folders(parent_folder_id: parent_id)
    files_result = api.list_files_in_folders([ parent_id ])

    {
      folders: folders_result[:folders] || [],
      files: files_result[:files] || [],
      error: nil
    }
  rescue StandardError => e
    Rails.logger.error("GoogleDriveBrowseService error: #{e.message}")
    { folders: [], files: [], error: e.message }
  end
end
