module RestrictedAccess
  extend ActiveSupport::Concern

  included do
    before_action :check_restricted_access
  end

  private

  def check_restricted_access
    if current_user&.restricted_access
      # Allow access to:
      # - Dashboard (shows restricted view)
      # - Chat (the only feature restricted users should use)
      # - Sessions (login/logout)
      # - Account settings
      # - API endpoints (for mobile app)
      allowed_controllers = %w[dashboard chat sessions account registrations api/v1/auth]

      unless allowed_controllers.include?(controller_path) || controller_name.in?(allowed_controllers)
        redirect_to root_path, alert: "You don't have access to that feature."
      end
    end
  end
end
