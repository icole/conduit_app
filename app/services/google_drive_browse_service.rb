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

  # List recent files across all folders the service account can access.
  # Uses a single API call with orderBy instead of recursive subfolder walking.
  # Returns { files: [...], error: nil }
  def recent_files(max_results: 5)
    api = GoogleDriveApiService.from_service_account
    query = "mimeType != 'application/vnd.google-apps.folder' and trashed = false"
    fields = "files(id, name, mimeType, modifiedTime, webViewLink, iconLink)"

    response = api.drive_service.list_files(
      q: query,
      order_by: "modifiedTime desc",
      page_size: max_results,
      fields: fields
    )

    files = (response.files || []).map do |file|
      {
        id: file.id,
        name: file.name,
        mime_type: file.mime_type,
        updated_at: file.modified_time,
        web_link: file.web_view_link,
        icon_link: file.icon_link
      }
    end

    { files: files, error: nil }
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
