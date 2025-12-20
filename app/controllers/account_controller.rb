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

  # Update password for users who already have one
  def update_password
    @user = current_user

    # Verify current password
    unless @user.authenticate(params[:current_password])
      redirect_to account_path, alert: "Current password is incorrect"
      return
    end

    # Update with new password
    if @user.update(password: params[:new_password], password_confirmation: params[:new_password_confirmation])
      redirect_to account_path, notice: "Password updated successfully"
    else
      redirect_to account_path, alert: @user.errors.full_messages.join(", ")
    end
  end

  # Set password for OAuth users who don't have one
  def set_password
    @user = current_user

    # Only allow if user doesn't have a password
    if @user.password_digest.present?
      redirect_to account_path, alert: "You already have a password set"
      return
    end

    # Set the password
    if @user.update(password: params[:new_password], password_confirmation: params[:new_password_confirmation])
      redirect_to account_path, notice: "Password set successfully"
    else
      redirect_to account_path, alert: @user.errors.full_messages.join(", ")
    end
  end
end
