# frozen_string_literal: true

class PasswordResetsController < ApplicationController
  # For members who can't sign in; the emailed token is the credential. The
  # community comes from the domain, or on the API domain (where the apps send
  # people, and where a self-created community's links point) from the token,
  # or from the accounts the email belongs to.
  skip_before_action :set_tenant_from_domain
  skip_before_action :authenticate_user!
  skip_before_action :verify_user_belongs_to_tenant!
  before_action :set_tenant_for_reset

  def new
    # Render email input form
  end

  def create
    accounts_for(params[:email].to_s.strip.downcase).each do |user|
      ActsAsTenant.with_tenant(user.community) do
        user.update!(password_reset_sent_at: Time.current)
        UserMailer.password_reset(user, JwtService.generate_password_reset_token(user)).deliver_later
      end
    end

    # Always show the same message to prevent email enumeration
    redirect_to password_reset_new_path, notice: "If an account exists with that email, we've sent reset instructions."
  end

  def edit
    @user = JwtService.verify_password_reset_token(params[:token])

    unless @user
      redirect_to password_reset_new_path, alert: "This reset link is invalid or has expired. Please request a new one."
      return
    end

    @token = params[:token]
  end

  def update
    @user = JwtService.verify_password_reset_token(params[:token])

    unless @user
      redirect_to password_reset_new_path, alert: "This reset link is invalid or has expired. Please request a new one."
      return
    end

    @token = params[:token]

    if params[:password].length < 8
      flash.now[:alert] = "Password must be at least 8 characters"
      render :edit, status: :unprocessable_entity
      return
    end

    if params[:password] != params[:password_confirmation]
      flash.now[:alert] = "Passwords don't match"
      render :edit, status: :unprocessable_entity
      return
    end

    ActsAsTenant.with_tenant(@user.community) do
      if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
        @user.update!(password_reset_sent_at: nil)
        @user.revoke_mobile_tokens!
        redirect_to login_path, notice: "Password updated successfully. You can now log in."
      else
        flash.now[:alert] = @user.errors.full_messages.join(", ")
        render :edit, status: :unprocessable_entity
      end
    end
  end

  private

  def set_tenant_for_reset
    community = find_community_by_host(request.host) || community_from_token
    return set_current_tenant(community) if community

    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false unless api_domain?(request.host)
  end

  def community_from_token
    decoded = JwtService.decode(params[:token].to_s)
    decoded && Community.find_by(id: decoded[:community_id])
  end

  # Without a community, every account the email has: each reset email links
  # to its own community
  def accounts_for(email)
    if current_community
      User.where("LOWER(email) = ?", email)
    else
      ActsAsTenant.without_tenant { User.where("LOWER(email) = ?", email).includes(:community).to_a }
    end
  end
end
