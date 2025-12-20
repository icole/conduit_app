class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Load posts only for non-restricted users
    if current_user.restricted_access
      @posts = Post.none  # Empty relation, no posts shown
      @post = nil         # Don't show the new post form
    else
      @posts = Post.order(created_at: :desc)
      @post = Post.new
    end

    # Show tasks created by the current user OR assigned to them
    @tasks = Task.where("assigned_to_user_id = ?", current_user.id)
    @tasks = @tasks.where(status: "active") if params[:status].blank?

    @task = Task.new

    # Check if the user already has a calendar share
    calendar_id = current_community.google_calendar_id
    @calendar_already_shared = calendar_id.present? && CalendarShare.calendar_shared_with_user?(calendar_id, current_user)

    # Check if the user already has a drive folder share
    folder_id = current_community.google_drive_folder_id
    @drive_folder_already_shared = folder_id.present? ? DriveShare.folder_shared_with_user?(folder_id, current_user) : false

    # Get recent drive files from cache or trigger background job
    @drive_sync_loading = false
    if !Rails.env.test? && @drive_folder_already_shared && folder_id.present?
      cache_key = "drive_files_#{current_user.id}"
      @recent_files = Rails.cache.read(cache_key)

      # If cache is empty or expired, trigger background job
      if @recent_files.nil?
        GoogleDriveSyncJob.perform_later(current_user.id)
        @recent_files = { status: :loading, files: [] }
        @drive_sync_loading = true
      end
    end

    @google_calendar_configured = begin
      defined?(CalendarCredentials) && CalendarCredentials.configured? && current_community.google_calendar_id.present?
    rescue
      false
    end

    if !Rails.env.test? && @google_calendar_configured
      begin
        auth = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: CalendarCredentials.credentials_io,
          scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
        service = GoogleCalendarApiService.new(auth)
        @events = service.get_events
      rescue => e
        Rails.logger.error("Failed to load calendar events: #{e.message}")
        @events = { events: [], status: :error, error: e.message }
      end
    else
      @events = { events: [], status: :not_configured }
    end
  end

  def refresh_drive_files
    folder_id = current_community.google_drive_folder_id

    if folder_id.present? && DriveShare.folder_shared_with_user?(folder_id, current_user)
      GoogleDriveSyncJob.perform_later(current_user.id)
      render json: { status: "success", message: "Refresh started" }
    else
      render json: { status: "error", message: "Access denied" }, status: :forbidden
    end
  end
end
