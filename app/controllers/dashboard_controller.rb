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

    @google_calendar_configured = begin
      defined?(CalendarCredentials) && CalendarCredentials.configured? && current_community.google_calendar_id.present?
    rescue
      false
    end

    if !Rails.env.test? && @google_calendar_configured
      begin
        service = GoogleCalendarApiService.from_service_account_with_acl_scope
        @events = service.get_events(max_results: 5)
      rescue StandardError => e
        Rails.logger.error("Failed to load calendar events: #{e.message}")
        @events = { events: [], status: :error, error: e.message }
      end
    else
      @events = { events: [], status: :not_configured }
    end
  end

  def documents_section
    @drive_files = []
    drive_service = GoogleDriveBrowseService.new(current_community)
    if drive_service.configured?
      result = drive_service.recent_files
      @drive_files = result[:files] || []
    end

    render partial: "dashboard/documents_section", layout: false
  end
end
