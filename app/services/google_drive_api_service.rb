# frozen_string_literal: true

require "google/apis/drive_v3"
require "googleauth"

# Service responsible for accessing Google Drive API and managing folder access
class GoogleDriveApiService
  attr_reader :drive_service

  def initialize(auth_credentials)
    @drive_service = Google::Apis::DriveV3::DriveService.new
    @drive_service.client_options.application_name = "Community Hub"
    @drive_service.authorization = auth_credentials
  end

  # Create from OAuth2 token (typically from user session)
  def self.from_oauth_token(access_token)
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"],
      scope: Google::Apis::DriveV3::AUTH_DRIVE_METADATA_READONLY,
      access_token: access_token
    )
    new(credentials)
  end

  # Create from service account key file (read-only access)
  def self.from_service_account
    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: CalendarCredentials.credentials_io,
      scope: Google::Apis::DriveV3::AUTH_DRIVE_METADATA_READONLY
    )
    new(credentials)
  end

  # Create from service account key file (with permissions management access)
  def self.from_service_account_with_permissions_scope
    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: CalendarCredentials.credentials_io,
      scope: Google::Apis::DriveV3::AUTH_DRIVE
    )
    new(credentials)
  end

  # List folders in a drive or parent folder
  def list_folders(parent_folder_id: "root", max_results: 100)
    begin
      # Query for folders only
      query = "mimeType = 'application/vnd.google-apps.folder'"
      query += " and '#{parent_folder_id}' in parents" if parent_folder_id != "root"

      response = drive_service.list_files(
        q: query,
        page_size: max_results,
        fields: "files(id, name, description, createdTime, modifiedTime, webViewLink, parents, permissions)"
      )

      format_folders(response.files)
    rescue Google::Apis::ClientError => e
      Rails.logger.error("Google Drive API Client Error: #{e.message}")
      { error: e.message, status: :client_error, folders: [] }
    rescue Google::Apis::ServerError => e
      Rails.logger.error("Google Drive API Server Error: #{e.message}")
      { error: e.message, status: :server_error, folders: [] }
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error("Google Drive API Authorization Error: #{e.message}")
      { error: e.message, status: :auth_error, folders: [] }
    end
  end

  # Get a specific folder by ID
  def get_folder(folder_id)
    begin
      folder = drive_service.get_file(
        folder_id,
        fields: "id, name, description, createdTime, modifiedTime, webViewLink, parents, permissions"
      )
      format_folder(folder)
    rescue Google::Apis::ClientError => e
      Rails.logger.error("Google Drive API Client Error: #{e.message}")
      { error: e.message, status: :client_error }
    rescue Google::Apis::ServerError => e
      Rails.logger.error("Google Drive API Server Error: #{e.message}")
      { error: e.message, status: :server_error }
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error("Google Drive API Authorization Error: #{e.message}")
      { error: e.message, status: :auth_error }
    end
  end

  # Share a folder with a specific user by email
  def share_folder_with_user(folder_id:, email:, role: "reader")
    begin
      # Create a new permission
      permission = Google::Apis::DriveV3::Permission.new(
        type: "user",
        email_address: email,
        role: role # Possible values: "reader", "writer", "commenter", "fileOrganizer", "organizer", "owner"
      )

      # Add the permission to the folder
      result = drive_service.create_permission(
        folder_id,
        permission,
        fields: "id",
        send_notification_email: true
      )

      # Return success result
      {
        status: :success,
        permission_id: result.id,
        email: email,
        role: role
      }
    rescue Google::Apis::ClientError => e
      Rails.logger.error("Google Drive API Permission Client Error: #{e.message}")
      { error: e.message, status: :client_error }
    rescue Google::Apis::ServerError => e
      Rails.logger.error("Google Drive API Permission Server Error: #{e.message}")
      { error: e.message, status: :server_error }
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error("Google Drive API Permission Authorization Error: #{e.message}")
      { error: e.message, status: :auth_error }
    end
  end

  private

  # Format a collection of folders for easier consumption
  def format_folders(folders)
    formatted_folders = folders.map { |folder| format_folder(folder) }
    { folders: formatted_folders, count: formatted_folders.length, status: :success }
  end

  # Format a single folder for easier consumption
  def format_folder(folder)
    return nil if folder.nil?

    {
      id: folder.id,
      name: folder.name,
      description: folder.description,
      created_at: folder.created_time,
      updated_at: folder.modified_time,
      web_link: folder.web_view_link,
      parents: folder.parents,
      permissions: folder.permissions&.map { |p| {
        id: p.id,
        type: p.type,
        email: p.email_address,
        role: p.role
      }}
    }
  end
end
