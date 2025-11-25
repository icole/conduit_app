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
    auth = request.env["omniauth.auth"]

    # Check if this is an account linking request (user already logged in)
    if current_user
      link_google_to_existing_account(auth)
      return
    end

    # Handle OAuth callback for login/signup
    invitation_token = session[:invitation_token]

    begin
      user = User.from_omniauth(auth, invitation_token)

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

  private

  def link_google_to_existing_account(auth)
    # Check if this Google account is already linked to another user
    existing_google_user = User.find_by(provider: auth.provider, uid: auth.uid)

    if existing_google_user && existing_google_user.id != current_user.id
      redirect_to account_path, alert: "This Google account is already linked to another user."
      return
    end

    # Link Google account to current user
    if current_user.update(
      provider: auth.provider,
      uid: auth.uid,
      avatar_url: auth.info.image
    )
      redirect_to account_path, notice: "Google account linked successfully! You now have access to Calendar and Drive features."
    else
      redirect_to account_path, alert: "Failed to link Google account: #{current_user.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    # Logout
    session[:user_id] = nil
    redirect_to root_path, notice: "Logged out successfully!"
  end
end
