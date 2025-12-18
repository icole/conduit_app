class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include RestrictedAccess
  include ActsAsTenant::ControllerExtensions

  # Set tenant from domain - must run before authenticate_user!
  set_current_tenant_through_filter
  before_action :set_tenant_from_domain
  before_action :authenticate_user!
  before_action :update_last_active, if: :user_signed_in?

  helper_method :current_user, :user_signed_in?, :google_account?, :current_community

  private

  def set_tenant_from_domain
    community = find_community_by_host(request.host)

    unless community
      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
      return
    end

    set_current_tenant(community)
  end

  def find_community_by_host(host)
    # Handle localhost in development
    if Rails.env.development? && host.include?("localhost")
      return Community.find_by(slug: "crow-woods")
    end

    # Handle test environment - use first community or look up by domain
    if Rails.env.test?
      return Community.find_by(domain: host) ||
             Community.find_by(slug: "crow-woods") ||
             Community.first
    end

    Community.find_by(domain: host) || Community.find_by(domain: host.gsub(/^www\./, ""))
  end

  def current_community
    ActsAsTenant.current_tenant
  end

  def current_user
    return @current_user if defined?(@current_user)
    return nil unless session[:user_id] && current_community

    # User.find_by is automatically scoped to current_community by acts_as_tenant
    @current_user = User.find_by(id: session[:user_id])
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
