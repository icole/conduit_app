# frozen_string_literal: true

class PasswordResetsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_user_belongs_to_tenant!

  def new
    # Render email input form
  end

  def create
    user = User.find_by(email: params[:email]&.downcase)

    if user
      user.update!(password_reset_sent_at: Time.current)
      token = JwtService.generate_password_reset_token(user)
      UserMailer.password_reset(user, token).deliver_later
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

    if params[:password].length < 6
      flash.now[:alert] = "Password must be at least 6 characters"
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
        redirect_to login_path, notice: "Password updated successfully. You can now log in."
      else
        flash.now[:alert] = @user.errors.full_messages.join(", ")
        render :edit, status: :unprocessable_entity
      end
    end
  end
end
