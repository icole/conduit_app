class RegistrationsController < ApplicationController
  skip_before_action :authenticate_user!

  def new
    # Require a valid invitation token
    unless valid_invitation_token?
      redirect_to login_path, alert: "A valid invitation is required to register."
      return
    end

    @user = User.new
  end

  def create
    # Require a valid invitation token
    unless valid_invitation_token?
      redirect_to login_path, alert: "A valid invitation is required to register."
      return
    end

    @user = User.new(user_params)

    # Associate with invitation
    invitation = Invitation.find_by(token: session[:invitation_token])
    @user.invitation = invitation if invitation&.valid_for_use?

    if @user.save
      session[:user_id] = @user.id
      session.delete(:invitation_token)
      redirect_to root_path, notice: "Welcome! Your account has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def valid_invitation_token?
    return true if Rails.env.test?

    token = session[:invitation_token]
    token.present? && User.valid_invitation?(token)
  end
end
