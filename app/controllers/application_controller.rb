class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include RestrictedAccess
  include ActsAsTenant::ControllerExtensions

  # Set tenant from domain - must run before authenticate_user!
  set_current_tenant_through_filter
  before_action :set_tenant_from_domain
  before_action :authenticate_user!
  before_action :verify_user_belongs_to_tenant!
  before_action :set_current_attributes
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

    # Handle API domain - determine community from logged-in user's session
    if api_domain?(host)
      return community_from_session
    end

    Community.find_by(domain: host) || Community.find_by(domain: host.gsub(/^www\./, ""))
  end

  def api_domain?(host)
    api_domain = ENV["CONDUIT_API_DOMAIN"] || "api.conduitcoho.app"
    host == api_domain
  end

  def community_from_session
    return nil unless session[:user_id]

    # Find user without tenant scope to get their community
    user = ActsAsTenant.without_tenant { User.find_by(id: session[:user_id]) }
    return nil unless user

    # If community_id is stored in session, verify it matches the user's actual community
    # This is a safety check to prevent any tampering or stale session data
    if session[:community_id] && session[:community_id] != user.community_id
      Rails.logger.error "[SECURITY] Session community_id mismatch! " \
        "Session has community_id: #{session[:community_id]}, " \
        "but user #{user.id} belongs to community: #{user.community_id}. " \
        "Using user's actual community for safety."
      # Don't use the session community_id - use the user's actual community
    end

    user.community
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

  # CRITICAL SECURITY CHECK: Verify the logged-in user belongs to the current tenant
  # This prevents any scenario where a user could see another community's data
  # Optimized: Only checks when tenant was set from domain (not API domain),
  # because API domain already uses user's actual community from session
  def verify_user_belongs_to_tenant!
    return unless user_signed_in?
    return unless current_community

    # Skip check for API domain - tenant is already set from user's community via session
    return if api_domain?(request.host)

    # For domain-based tenants, verify user belongs to this domain's community
    # Use @current_user if already loaded to avoid extra query
    user_community_id = @current_user&.community_id || session_user_community_id

    if user_community_id && user_community_id != current_community.id
      Rails.logger.error "[SECURITY] Tenant mismatch detected! " \
        "User #{session[:user_id]} belongs to community #{user_community_id} " \
        "but accessing domain for community #{current_community.id} (#{current_community.slug}). " \
        "Request host: #{request.host}. User agent: #{request.user_agent}"

      # Clear the session to prevent further issues
      reset_session

      # Fail the request - do NOT show any data
      render plain: "Access denied - wrong community", status: :forbidden
    end
  end

  # Helper to get user's community_id without loading full user object
  def session_user_community_id
    return nil unless session[:user_id]
    ActsAsTenant.without_tenant do
      User.where(id: session[:user_id]).pick(:community_id)
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

  def set_current_attributes
    Current.user = current_user
    Current.community = current_community
  end
end
