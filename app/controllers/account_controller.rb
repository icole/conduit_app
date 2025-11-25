class AccountController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def unlink_google
    if current_user.provider == "google_oauth2"
      # Check if user has a password set (they need one to unlink)
      if current_user.password_digest.blank?
        redirect_to account_path, alert: "Please set a password before unlinking your Google account."
        return
      end

      current_user.update!(provider: nil, uid: nil)
      redirect_to account_path, notice: "Google account unlinked successfully."
    else
      redirect_to account_path, alert: "No Google account linked."
    end
  end
end
