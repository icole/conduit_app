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
          # Verify ID token if provided (more secure)
          if params[:id_token].present?
            verified_data = verify_google_id_token(params[:id_token])
            if verified_data
              email = verified_data["email"]
              name = verified_data["name"]
              image_url = verified_data["picture"]
            else
              render json: { error: "Invalid Google ID token" }, status: :unauthorized
              return
            end
          else
            # Fallback to trusting provided data (less secure, for development)
            Rails.logger.warn "Google auth without ID token verification - less secure"
            email = params[:email]
            name = params[:name]
            image_url = params[:image_url]
          end

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
        # Generate secure JWT token with expiration
        JwtService.generate_auth_token(user)
      end

      def verify_auth_token(token)
        # Verify JWT token and return user
        JwtService.verify_auth_token(token)
      end

      def verify_google_id_token(id_token)
        # Accept Web, iOS, and Android client IDs from environment variables
        valid_client_ids = [
          ENV["GOOGLE_CLIENT_ID"],           # Web client ID
          ENV["GOOGLE_IOS_CLIENT_ID"],       # iOS client ID
          ENV["GOOGLE_ANDROID_CLIENT_ID"]    # Android client ID
        ].compact.uniq

        if valid_client_ids.empty?
          Rails.logger.error "No Google Client IDs configured in environment variables"
          return nil
        end

        begin
          # Use Google's token verification endpoint
          uri = URI("https://oauth2.googleapis.com/tokeninfo?id_token=#{id_token}")

          # Create HTTP connection with proper SSL handling
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          # In development, disable SSL verification to avoid certificate issues
          # In production, keep SSL verification enabled
          if Rails.env.development?
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          else
            http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          end

          request = Net::HTTP::Get.new(uri)
          response = http.request(request)

          if response.code == "200"
            data = JSON.parse(response.body)

            # Verify the audience matches one of our client IDs (Web, iOS, or Android)
            if valid_client_ids.include?(data["aud"])
              Rails.logger.info "Google ID token verified for audience: #{data['aud']}"
              return data
            else
              Rails.logger.error "Google ID token has invalid audience: #{data['aud']}"
              Rails.logger.error "Expected one of: #{valid_client_ids.join(', ')}"
            end
          else
            Rails.logger.error "Google ID token verification failed: #{response.code}"
          end
        rescue => e
          Rails.logger.error "Error verifying Google ID token: #{e.message}"
        end

        nil
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
