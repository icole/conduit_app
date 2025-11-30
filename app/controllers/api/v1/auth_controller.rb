# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_user!
      before_action :authenticate_api_user!, only: [ :stream_token, :check, :logout, :establish_session ]

      # POST /api/v1/login
      def login
        user = User.find_by(email: params[:email]&.downcase)

        if user&.authenticate(params[:password])
          # Set session for the user
          session[:user_id] = user.id

          # For mobile apps, ensure cookie persists
          if request.user_agent&.include?("Conduit")
            session.options[:expire_after] = 30.days
          end

          # Generate an auth token for the mobile app
          auth_token = generate_auth_token(user)

          render json: {
            success: true,
            user: {
              id: user.id,
              email: user.email,
              name: user.name
            },
            auth_token: auth_token,
            session_cookie: session.id
          }, status: :ok
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      # GET /api/v1/auth/check
      def check
        if @current_user
          render json: {
            authenticated: true,
            user: {
              id: @current_user.id,
              email: @current_user.email,
              name: @current_user.name
            }
          }, status: :ok
        else
          render json: { authenticated: false }, status: :unauthorized
        end
      end

      # DELETE /api/v1/logout
      def logout
        session[:user_id] = nil
        render json: { success: true }, status: :ok
      end

      # POST /api/v1/establish_session
      # Creates a Rails session from auth token for WebView
      def establish_session
        if @current_user
          # Reset the session to ensure clean state
          reset_session

          # Set the session
          session[:user_id] = @current_user.id

          # Force session to be created
          session[:established_at] = Time.current.to_i

          # Log session details for debugging
          Rails.logger.info "Session established for user #{@current_user.id}"
          Rails.logger.info "Session ID: #{session.id}"

          render json: {
            success: true,
            user: {
              id: @current_user.id,
              email: @current_user.email,
              name: @current_user.name
            },
            session_id: session.id,
            session_established: true
          }, status: :ok
        else
          render json: { error: "Not authenticated" }, status: :unauthorized
        end
      end

      # GET /api/v1/stream_token
      def stream_token
        unless StreamChatClient.configured?
          render json: {
            error: "Stream Chat is not configured",
            configured: false
          }, status: :service_unavailable
          return
        end

        if @current_user
          # Sync user to Stream first
          sync_user_to_stream

          # Ensure user is in default channels
          StreamChannelService.ensure_user_in_default_channels(@current_user)

          # Generate token
          token = StreamChatClient.client.create_token(@current_user.id.to_s)

          render json: {
            token: token,
            user: {
              id: @current_user.id.to_s,
              name: @current_user.name,
              avatar: @current_user.avatar_url
            },
            api_key: StreamChatClient.api_key
          }, status: :ok
        else
          render json: { error: "Not authenticated" }, status: :unauthorized
        end
      end

      # POST /api/v1/google_auth
      def google_auth
        # Verify the Google ID token
        begin
          # In production, you should verify the ID token with Google
          # For now, we'll use the provided user info
          email = params[:email]
          name = params[:name]
          image_url = params[:image_url]

          # First, check if user already exists with this email (regardless of provider)
          user = User.find_by(email: email.downcase)

          Rails.logger.info "Google Auth: email=#{email}, existing_user=#{user.present?}"

          if user
            # Existing user - update their OAuth info if not already set
            user.update(
              provider: user.provider || "google_oauth2",
              uid: user.uid || params[:email],
              avatar_url: user.avatar_url.presence || image_url,
              name: user.name.presence || name
            )
          else
            # New user - create with Google OAuth info
            user = User.new(
              email: email.downcase,
              name: name,
              password: SecureRandom.hex(16), # Random password for OAuth users
              provider: "google_oauth2",
              uid: params[:email], # Using email as UID for simplicity
              avatar_url: image_url
            )

            # Check invitation requirement only for truly new users
            if !Rails.env.test? && !User.valid_invitation?(params[:invitation_token])
              render json: { error: "Access restricted to invited users only" }, status: :forbidden
              return
            end

            user.save!
          end

          # Set session with extended expiry for mobile apps
          session[:user_id] = user.id

          # For mobile apps, ensure cookie persists
          if request.user_agent&.include?("Conduit")
            session.options[:expire_after] = 30.days
          end

          # Generate an auth token for the mobile app
          auth_token = generate_auth_token(user)

          render json: {
            success: true,
            user: {
              id: user.id,
              email: user.email,
              name: user.name,
              avatar_url: user.avatar_url
            },
            auth_token: auth_token,
            session_cookie: session.id
          }, status: :ok
        rescue => e
          Rails.logger.error "Google auth error: #{e.message}"
          render json: { error: "Authentication failed" }, status: :unauthorized
        end
      end

      private

      def authenticate_api_user!
        # Try auth token first
        auth_header = request.headers["Authorization"]

        if auth_header.present? && auth_header.start_with?("Bearer ")
          token = auth_header.split(" ").last
          user = verify_auth_token(token)

          if user
            @current_user = user
            return
          end
        end

        # Fall back to session authentication
        if current_user
          @current_user = current_user
        else
          render json: {
            error: "Authentication required",
            login_url: "#{request.base_url}/login"
          }, status: :unauthorized
        end
      end

      def generate_auth_token(user)
        # Generate a simple JWT-like token
        # In production, use proper JWT with expiration
        payload = {
          user_id: user.id,
          email: user.email,
          issued_at: Time.current.to_i
        }

        # Simple base64 encoding for now - in production use proper JWT
        Base64.strict_encode64(payload.to_json)
      end

      def verify_auth_token(token)
        # Decode and verify the token
        begin
          decoded = Base64.strict_decode64(token)
          payload = JSON.parse(decoded)
          User.find_by(id: payload["user_id"])
        rescue => e
          Rails.logger.error "Invalid auth token: #{e.message}"
          nil
        end
      end

      def sync_user_to_stream
        StreamChatClient.client.upsert_user({
          id: @current_user.id.to_s,
          name: @current_user.name,
          image: @current_user.avatar_url,
          role: @current_user.admin? ? "admin" : "user"
        })
      rescue StreamChat::StreamAPIException => e
        Rails.logger.error "Failed to sync user to Stream: #{e.message}"
        raise e
      end
    end
  end
end
