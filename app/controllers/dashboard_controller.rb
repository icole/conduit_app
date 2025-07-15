class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @posts = Post.order(created_at: :desc)
    @post = Post.new

    # Show tasks created by the current user OR assigned to them
    @tasks = Task.where("assigned_to_user_id = ?", current_user.id)
    @tasks = @tasks.where(status: "pending") if params[:status].blank?

    @task = Task.new

    # Check if the user already has a calendar share
    calendar_id = ENV["GOOGLE_CALENDAR_ID"]
    @calendar_already_shared = CalendarShare.calendar_shared_with_user?(calendar_id, current_user)

    # Check if the user already has a drive folder share
    folder_id = ENV["GOOGLE_DRIVE_FOLDER_ID"]
    @drive_folder_already_shared = folder_id.present? ? DriveShare.folder_shared_with_user?(folder_id, current_user) : false

    # Get recent drive files if user has access to the folder
    if !Rails.env.test? && @drive_folder_already_shared && folder_id.present?
      begin
        drive_service = GoogleDriveApiService.from_service_account
        @recent_files = drive_service.list_recent_files(folder_id)
      rescue StandardError => e
        Rails.logger.error("Failed to fetch recent drive files: #{e.message}")
        @recent_files = { error: e.message, status: :error, files: [] }
      end
    end

    if !Rails.env.test?
      auth = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: CalendarCredentials.credentials_io,
        scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
      service = GoogleCalendarApiService.new(auth)
      @events = service.get_events
    else
      @events = { events: [], status: :success }
    end
  end
end
