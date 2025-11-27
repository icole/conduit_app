class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :update_last_active, if: :user_signed_in?

  helper_method :current_user, :user_signed_in?, :google_account?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    !!current_user
  end

  def authenticate_user!
    unless user_signed_in?
      # Store the intended destination URL to redirect back after login
      if request.get?
        session[:return_to] = request.fullpath
        Rails.logger.info "Auth required - storing return_to: #{request.fullpath}, user_agent: #{request.user_agent}"
      end
      redirect_to login_path, alert: "You must be logged in to access this page."
    end
  end

  def authorize_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end

  def google_account?
    current_user&.google_account?
  end

  def require_google_account!
    unless google_account?
      redirect_back fallback_location: root_path,
        alert: "This feature requires a Google account. Please sign in with Google to access Google Calendar and Drive integrations."
    end
  end

  def update_last_active
    # Only update if the last update was more than 5 minutes ago to avoid too many DB writes
    if current_user.last_active_at.nil? || current_user.last_active_at < 5.minutes.ago
      current_user.update_column(:last_active_at, Time.current)
    end
  end
end
