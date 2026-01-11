# frozen_string_literal: true

require "google/apis/drive_v3"
require "googleauth"
require "set"

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

  # Get recent files in a folder and all its subfolders
  def list_recent_files(folder_id, max_results: 5)
    begin
      # To search recursively through all subfolders, we need to use a different approach
      # since Drive API doesn't directly support recursive searches in a single query

      # We'll collect all files and then manually sort them
      all_files = []
      fields = "files(id, name, mimeType, createdTime, modifiedTime, webViewLink, iconLink, fileExtension, size, parents)"

      # Start with files in the main folder
      query = "mimeType != 'application/vnd.google-apps.folder' and trashed = false and '#{folder_id}' in parents"
      top_level_response = drive_service.list_files(
        q: query,
        fields: fields
      )
      all_files.concat(top_level_response.files) if top_level_response.files

      # Get a list of all subfolders
      subfolders = list_all_subfolders(folder_id)

      # Add files from each subfolder
      subfolders.each do |subfolder|
        begin
          query = "mimeType != 'application/vnd.google-apps.folder' and trashed = false and '#{subfolder[:id]}' in parents"
          folder_response = drive_service.list_files(
            q: query,
            fields: fields
          )
          all_files.concat(folder_response.files) if folder_response.files
        rescue StandardError => e
          Rails.logger.warn("Error getting files from subfolder #{subfolder[:id]}: #{e.message}")
        end
      end

      # Sort all files by modified time (most recent first)
      all_files.sort_by! { |file| file.modified_time || Time.at(0) }.reverse!

      # Take only the max_results most recent files
      all_files = all_files.first(max_results)

      format_files(all_files)
    rescue Google::Apis::ClientError => e
      Rails.logger.error("Google Drive API Client Error: #{e.message}")
      { error: e.message, status: :client_error, files: [] }
    rescue Google::Apis::ServerError => e
      Rails.logger.error("Google Drive API Server Error: #{e.message}")
      { error: e.message, status: :server_error, files: [] }
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error("Google Drive API Authorization Error: #{e.message}")
      { error: e.message, status: :auth_error, files: [] }
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

  # Format a collection of files for easier consumption
  def format_files(files)
    formatted_files = files.map { |file| format_file(file) }
    { files: formatted_files, count: formatted_files.length, status: :success }
  end

  # Format a single file for easier consumption
  def format_file(file)
    return nil if file.nil?

    {
      id: file.id,
      name: file.name,
      mime_type: file.mime_type,
      created_at: file.created_time,
      updated_at: file.modified_time,
      web_link: file.web_view_link,
      icon_link: file.icon_link,
      file_extension: file.file_extension,
      size: file.size
    }
  end

  # Helper method to list all subfolders recursively
  def list_all_subfolders(folder_id)
    all_subfolders = []
    folders_to_process = [ folder_id ]
    processed_folders = Set.new

    until folders_to_process.empty?
      current_folder = folders_to_process.shift
      next if processed_folders.include?(current_folder)
      processed_folders.add(current_folder)

      begin
        # Get direct subfolders of the current folder
        query = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and '#{current_folder}' in parents"
        response = drive_service.list_files(
          q: query,
          fields: "files(id, name)"
        )

        if response.files && response.files.any?
          response.files.each do |subfolder|
            all_subfolders << { id: subfolder.id, name: subfolder.name }
            folders_to_process << subfolder.id
          end
        end
      rescue StandardError => e
        Rails.logger.warn("Error getting subfolders for folder #{current_folder}: #{e.message}")
      end
    end

    all_subfolders
  end
end
