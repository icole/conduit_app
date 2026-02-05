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

    @recent_documents = Document.order(updated_at: :desc).limit(5)

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
        @events = service.get_events(max_results: 5)
      rescue StandardError => e
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
      ScheduledDriveSyncJob.perform_later
      render json: { status: "success", message: "Refresh started" }
    else
      render json: { status: "error", message: "Access denied" }, status: :forbidden
    end
  end
end
