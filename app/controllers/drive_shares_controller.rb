# frozen_string_literal: true

class DriveSharesController < ApplicationController
  before_action :authenticate_user!

  # Share a drive folder with the current user
  def create
    folder_id = params[:folder_id] || ENV["GOOGLE_DRIVE_FOLDER_ID"]
    folder_name = params[:folder_name]

    Rails.logger.info("Attempting to share drive folder '#{folder_id}' with user: #{current_user.email}")

    # Verify the required configuration is available
    unless folder_id.present?
      Rails.logger.error("Missing folder_id parameter or GOOGLE_DRIVE_FOLDER_ID environment variable")
      return redirect_back(fallback_location: root_path, alert: "Drive folder configuration incomplete. Please contact the administrator.")
    end

    # Check if folder is already shared with this user
    if DriveShare.folder_shared_with_user?(folder_id, current_user)
      Rails.logger.info("Drive folder '#{folder_id}' already shared with user: #{current_user.email}")
      return redirect_back(
        fallback_location: root_path,
        notice: "You already have access to this folder."
      )
    end

    # Make sure we have drive credentials available
    begin
      # Get service with write access to drive permissions
      service = GoogleDriveApiService.from_service_account_with_permissions_scope

      # Get role from params or default to reader
      role = params[:role].presence || "reader"

      # Attempt to share the folder with the current user
      result = service.share_folder_with_user(
        folder_id: folder_id,
        email: current_user.email,
        role: role
      )

      Rails.logger.info("Drive folder sharing result: #{result.inspect}")

      if result[:status] == :success
        # If we don't have the folder name yet, try to fetch it
        if folder_name.blank?
          folder_info = service.get_folder(folder_id)
          folder_name = folder_info[:name] if folder_info[:status] == :success
        end

        # Record the successful folder share
        DriveShare.create!(
          user: current_user,
          folder_id: folder_id,
          folder_name: folder_name,
          permission_id: result[:permission_id],
          role: role,
          shared_at: Time.current
        )

        session[:shared_folder_id] = folder_id
        session[:shared_folder_name] = folder_name

        redirect_to success_drive_shares_path
      else
        redirect_back(
          fallback_location: root_path,
          alert: "Could not share folder: #{result[:error]}"
        )
      end
    rescue StandardError => e
      Rails.logger.error("Drive folder sharing error: #{e.message}\n#{e.backtrace.join("\n")}")
      redirect_back(
        fallback_location: root_path,
        alert: "An error occurred while trying to share the folder. Please try again later."
      )
    end
  end

  # Show success page after folder has been shared
  def success
    @folder_id = session.delete(:shared_folder_id)
    @folder_name = session.delete(:shared_folder_name) || "Shared Folder"
  end

  # List available folders (admin only)
  def index
    authorize_admin!

    begin
      service = GoogleDriveApiService.from_service_account
      @folder_results = service.list_folders(
        parent_folder_id: params[:parent_id],
        max_results: 50
      )
    rescue StandardError => e
      Rails.logger.error("Error listing folders: #{e.message}")
      @folder_results = { error: e.message, status: :error, folders: [] }
    end
  end
end
