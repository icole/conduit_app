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

    # Load recent files from Google Drive for the documents widget
    @drive_files = []
    drive_service = GoogleDriveBrowseService.new(current_community)
    if drive_service.configured?
      result = drive_service.list_contents
      @drive_files = (result[:files] || []).sort_by { |f| f[:updated_at] || Time.at(0) }.reverse.first(5)
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
        @events = service.get_events(max_results: 5)
      rescue StandardError => e
        Rails.logger.error("Failed to load calendar events: #{e.message}")
        @events = { events: [], status: :error, error: e.message }
      end
    else
      @events = { events: [], status: :not_configured }
    end
  end
end
