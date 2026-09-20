# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_user!
      skip_before_action :set_tenant_from_domain
      before_action :set_tenant_from_jwt, only: [ :stream_token, :check, :logout, :establish_session ]
      before_action :authenticate_api_user!, only: [ :stream_token, :check, :logout, :establish_session ]
      # Tenant comes from the JWT above, so the suspension check must run after it.
      # Logout stays allowed so a suspended member can still revoke their token.
      before_action :enforce_community_status, only: [ :stream_token, :check, :establish_session ]

      # POST /api/v1/login
      def login
        community = required_community or return

        # Email is only unique per community, so the lookup must be scoped.
        user = ActsAsTenant.with_tenant(community) do
          User.find_by(email: params[:email]&.downcase)
        end

        if user&.authenticate(params[:password])
          # Set tenant for the user's community
          set_current_tenant(user.community)

          # Clear any existing session first to prevent stale data
          reset_session

          # Set session for the user with their community
          session[:user_id] = user.id
          session[:community_id] = user.community_id

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

      # POST /api/v1/auth/refresh
      # Accepts an expired (but validly-signed) JWT within 7-day grace window
      # Returns a fresh auth token
      REFRESH_GRACE_PERIOD = 7.days

      def refresh
        auth_header = request.headers["Authorization"]

        unless auth_header.present? && auth_header.start_with?("Bearer ")
          render json: { error: "invalid_token" }, status: :unauthorized
          return
        end

        token = auth_header.split(" ").last

        # Decode ignoring expiry (but still verifying signature)
        decoded = JwtService.decode_expired(token)

        unless decoded && decoded[:type] == "auth"
          render json: { error: "invalid_token" }, status: :unauthorized
          return
        end

        # Reject if token is still valid (not expired)
        unless JwtService.token_expired?(token)
          render json: { error: "token_not_expired" }, status: :unauthorized
          return
        end

        # Check grace window: expired no more than 7 days ago
        expired_at = Time.at(decoded[:exp])
        if expired_at < REFRESH_GRACE_PERIOD.ago
          render json: { error: "token_expired_beyond_refresh" }, status: :unauthorized
          return
        end

        # Verify user still exists and the token hasn't been revoked
        user = JwtService.user_for_auth_claims(decoded)

        unless user
          render json: { error: "invalid_token" }, status: :unauthorized
          return
        end

        # Issue fresh token
        new_token = JwtService.generate_auth_token(user)

        render json: {
          auth_token: new_token,
          user: {
            id: user.id,
            email: user.email,
            name: user.name
          }
        }, status: :ok
      end

      # DELETE /api/v1/logout
      def logout
        @current_user.revoke_mobile_tokens!
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

          Rails.logger.info "Session established for user #{@current_user.id}"

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
          unless @current_user.community.chat_available?
            render json: { error: "community_not_active", status: @current_user.community.status }, status: :forbidden
            return
          end

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
            api_key: StreamChatClient.api_key,
            community_slug: @current_user.community.slug
          }, status: :ok
        else
          render json: { error: "Not authenticated" }, status: :unauthorized
        end
      end

      # POST /api/v1/google_auth
      def google_auth
        # The ID token is the only thing we trust. Identity comes from the
        # verified token claims, never from other request params.
        if params[:id_token].blank?
          render json: { error: "Google ID token is required" }, status: :bad_request
          return
        end

        community = required_community or return

        begin
          verified_data = GoogleIdTokenVerifier.verify(params[:id_token])
          unless verified_data
            render json: { error: "Invalid Google ID token" }, status: :unauthorized
            return
          end

          unless verified_data["email_verified"].to_s == "true"
            render json: { error: "Google account email is not verified" }, status: :unauthorized
            return
          end

          email = verified_data["email"]
          name = verified_data["name"]
          image_url = verified_data["picture"]
          google_uid = verified_data["sub"]  # Google's unique user ID

          # Look the user up inside the named community only: email is unique
          # per community, not globally.
          #   1. By email (primary lookup)
          #   2. By Google UID (for users who linked a different Google account)
          user = ActsAsTenant.with_tenant(community) do
            User.find_by(email: email.downcase) ||
              (google_uid.present? && User.find_by(provider: "google_oauth2", uid: google_uid))
          end

          Rails.logger.info "Google Auth: community=#{community.slug} existing_user=#{user.present?}"

          if user
            # Set tenant for the user's community
            set_current_tenant(user.community)

            # Existing user - update their OAuth info if not already set
            user.update(
              provider: user.provider || "google_oauth2",
              uid: user.uid || google_uid,
              avatar_url: user.avatar_url.presence || image_url,
              name: user.name.presence || name
            )
          else
            # New user - set tenant before creating
            set_current_tenant(community)

            # New accounts need a valid invitation
            unless User.valid_invitation?(params[:invitation_token])
              render json: { error: "Access restricted to invited users only" }, status: :forbidden
              return
            end

            # Create with Google OAuth info
            user = User.new(
              email: email.downcase,
              name: name,
              password: SecureRandom.hex(16), # Random password for OAuth users
              provider: "google_oauth2",
              uid: google_uid,
              avatar_url: image_url
            )

            user.save!
          end

          # Clear any existing session first to prevent stale data
          reset_session

          # Set session with extended expiry for mobile apps
          session[:user_id] = user.id
          session[:community_id] = user.community_id

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
        rescue StandardError => e
          Rails.logger.error "Google auth error: #{e.message}"
          render json: { error: "Authentication failed" }, status: :unauthorized
        end
      end

      private

      # The community a login is scoped to. Renders the error and returns nil
      # when it is missing or unknown, so callers can `or return`.
      def required_community
        domain = params[:community_domain]
        if domain.blank?
          render json: { error: "community_domain_required" }, status: :bad_request
          return nil
        end

        community = community_from_domain(domain)
        unless community
          render json: { error: "User not found in this community" }, status: :unauthorized
          return nil
        end

        community
      end

      # Strict domain lookup, except that local development maps localhost and
      # the Android emulator host to the dev community (mirrors find_community_by_host).
      def community_from_domain(domain)
        if Rails.env.development? && (domain.include?("localhost") || domain == "10.0.2.2")
          return Community.find_by(slug: "crow-woods")
        end

        Community.find_by(domain: domain) || Community.find_by(domain: domain.sub(/\Awww\./, ""))
      end

      def set_tenant_from_jwt
        auth_header = request.headers["Authorization"]
        return unless auth_header.present? && auth_header.start_with?("Bearer ")

        token = auth_header.split(" ").last
        decoded = JwtService.decode(token)
        return unless decoded && decoded[:community_id]

        community = Community.find_by(id: decoded[:community_id])
        set_current_tenant(community) if community
      end

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

      def sync_user_to_stream
        StreamChatClient.client.upsert_user(@current_user.stream_user_data)
      rescue StreamChat::StreamAPIException => e
        Rails.logger.error "Failed to sync user to Stream: #{e.message}"
        raise e
      end
    end
  end
end
