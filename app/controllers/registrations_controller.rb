class RegistrationsController < ApplicationController
  include TenantFromInvitation

  # Registering happens with no session beyond the accepted invitation, which
  # is what tells us which community the new member is joining.
  skip_before_action :set_tenant_from_domain
  skip_before_action :verify_user_belongs_to_tenant!
  before_action :set_tenant_from_invitation_or_domain

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
      @user.send_email_verification!
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

  def invitation_token_for_tenant
    session[:invitation_token]
  end

  def valid_invitation_token?
    token = session[:invitation_token]
    token.present? && User.valid_invitation?(token)
  end
end
