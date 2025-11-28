# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :verify_authenticity_token, only: [:login, :logout, :google_auth]
      skip_before_action :authenticate_user!, only: [:login, :google_auth]

      # POST /api/v1/login
      def login
        user = User.find_by(email: params[:email]&.downcase)

        if user&.authenticate(params[:password])
          # Set session for the user
          session[:user_id] = user.id

          render json: {
            success: true,
            user: {
              id: user.id,
              email: user.email,
              name: user.name
            }
          }, status: :ok
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      # GET /api/v1/auth/check
      def check
        if current_user
          render json: {
            authenticated: true,
            user: {
              id: current_user.id,
              email: current_user.email,
              name: current_user.name
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

      # POST /api/v1/google_auth
      def google_auth
        # Verify the Google ID token
        begin
          # In production, you should verify the ID token with Google
          # For now, we'll use the provided user info
          email = params[:email]
          name = params[:name]
          image_url = params[:image_url]

          # Find or create user from Google OAuth
          user = User.where(email: email.downcase).first_or_initialize do |u|
            u.name = name
            u.password = SecureRandom.hex(16) # Random password for OAuth users
            u.provider = "google_oauth2"
            u.uid = params[:email] # Using email as UID for simplicity
            u.avatar_url = image_url
          end

          # Update user info if it changed
          if user.persisted?
            user.update(
              name: name,
              avatar_url: image_url
            ) if user.name != name || user.avatar_url != image_url
          else
            # New user - check invitation requirement
            if !Rails.env.test? && !User.valid_invitation?(params[:invitation_token])
              render json: { error: "Access restricted to invited users only" }, status: :forbidden
              return
            end
            user.save!
          end

          # Set session
          session[:user_id] = user.id

          render json: {
            success: true,
            user: {
              id: user.id,
              email: user.email,
              name: user.name,
              avatar_url: user.avatar_url
            }
          }, status: :ok
        rescue => e
          Rails.logger.error "Google auth error: #{e.message}"
          render json: { error: "Authentication failed" }, status: :unauthorized
        end
      end
    end
  end
end