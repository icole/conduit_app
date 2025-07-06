class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @posts = Post.order(created_at: :desc)
    @post = Post.new

    # Show tasks created by the current user OR assigned to them
    @tasks = Task.where("assigned_to_user_id = ?", current_user.id)
    @tasks = @tasks.where(status: "pending") if params[:status].blank?

    @task = Task.new
    auth = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(ENV["CALENDAR_CONFIG_FILE"]),
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
    service = GoogleCalendarApiService.new(auth)
    @events = service.get_events
  end
end
