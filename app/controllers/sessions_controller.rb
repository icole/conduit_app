class SessionsController < ApplicationController
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
    user = User.from_omniauth(request.env["omniauth.auth"])

    if user.save
      session[:user_id] = user.id
      redirect_to root_path, notice: "Logged in with Google successfully!"
    else
      redirect_to login_path, alert: "Failed to log in with Google: #{user.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    # Logout
    session[:user_id] = nil
    redirect_to root_path, notice: "Logged out successfully!"
  end
end
