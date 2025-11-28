# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :verify_authenticity_token, only: [:login, :logout]
      skip_before_action :authenticate_user!, only: [:login]

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
    end
  end
end