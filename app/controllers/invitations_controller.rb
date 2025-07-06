class InvitationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invitation, only: [ :accept ]
  skip_before_action :authenticate_user!, only: [ :accept ]
  before_action :admin_only, except: [ :accept ]

  def new
    # If we already have an active invitation, redirect to it
    active_invitation = Invitation.where("expires_at > ?", Time.current).order(created_at: :desc).first
    redirect_to invitations_path and return if active_invitation.present?

    @invitation = Invitation.new
  end

  def create
    @invitation = Invitation.new(invitation_params)
    @invitation.generate_token
    if !@invitation.expires_at.present?
      @invitation.set_expiration
    end

    if @invitation.save
      redirect_to invitations_path, notice: "New invitation link was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def index
    @active_invitation = Invitation.where("expires_at > ?", Time.current).order(created_at: :desc).first
  end

  def accept
    if @invitation.nil?
      redirect_to login_path, alert: "Invalid invitation link."
      return
    end

    if @invitation.expired?
      redirect_to login_path, alert: "This invitation link has expired."
      return
    end

    # Store the invitation token in the session for use during registration
    session[:invitation_token] = @invitation.token

    # Redirect to registration page
    # redirect_to login_path, notice: "Please complete your registration."
    render :accept
  end

  private

  def invitation_params
    params.require(:invitation).permit(:expires_at)
  end

  def set_invitation
    @invitation = Invitation.find_by(token: params[:id])
  end

  def admin_only
    unless current_user&.admin?
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end
end
