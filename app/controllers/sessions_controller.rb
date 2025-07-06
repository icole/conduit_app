class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create, :omniauth ]

  def new
    # Login page
  end

  def create
    # Regular login with email/password
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_path, notice: "Logged in successfully!"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def omniauth
    # Handle OAuth callback
    invitation_token = session[:invitation_token]

    begin
      user = User.from_omniauth(request.env["omniauth.auth"], invitation_token)

      if user.save
        session[:user_id] = user.id
        session.delete(:invitation_token) if invitation_token.present?
        redirect_to root_path, notice: "Logged in with Google successfully!"
      else
        redirect_to login_path, alert: "Failed to log in with Google: #{user.errors.full_messages.join(', ')}"
      end
    rescue StandardError => e
      redirect_to login_path, alert: "Authentication failed: #{e.message}"
    end
  end

  def destroy
    # Logout
    session[:user_id] = nil
    redirect_to root_path, notice: "Logged out successfully!"
  end
end
