module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Use unscoped to bypass acts_as_tenant scoping
      # ActionCable connections don't go through ApplicationController
      # where the tenant is normally set from the domain
      if verified_user = User.unscoped.find_by(id: request.session[:user_id])
        verified_user
      else
        reject_unauthorized_connection
      end
    end
  end
end
