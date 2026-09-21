# frozen_string_literal: true

class EmailVerificationsController < ApplicationController
  # The link in the email may be opened on any host, logged in or not: the
  # token carries the community, so resolve the tenant from it instead.
  skip_before_action :set_tenant_from_domain, only: :show
  skip_before_action :authenticate_user!, only: :show
  skip_before_action :verify_user_belongs_to_tenant!, only: :show
  before_action :set_tenant_from_token, only: :show

  # GET /email_verification/:token
  def show
    user = JwtService.verify_email_verification_token(params[:token])

    if user
      user.verify_email!
      redirect_to root_path, notice: "Your email address is verified. Thanks!"
    else
      redirect_to root_path, alert: "That verification link is invalid or has expired. Log in and request a new one."
    end
  end

  # POST /email_verification/resend
  def resend
    current_user.send_email_verification!
    redirect_to root_path, notice: "Verification email sent to #{current_user.email}."
  end

  private

  def set_tenant_from_token
    decoded = JwtService.decode(params[:token].to_s)
    community = decoded && Community.find_by(id: decoded[:community_id])
    set_current_tenant(community) if community
  end
end
