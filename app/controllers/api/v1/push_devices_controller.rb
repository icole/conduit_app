# frozen_string_literal: true

module Api
  module V1
    # The apps register their push notification token here after signing in,
    # and remove it when signing out, so the server can send task reminders.
    class PushDevicesController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_user!
      skip_before_action :set_tenant_from_domain
      skip_before_action :verify_user_belongs_to_tenant!
      before_action :authenticate_app_user!

      # POST /api/v1/push_devices { token, platform: "apple"|"google", name }
      def create
        device = ApplicationPushDevice.find_or_initialize_by(token: params[:token], platform: params[:platform])
        device.assign_attributes(owner: @app_user, name: params[:name].presence || device.name)

        if device.save
          head :created
        else
          render json: { errors: device.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ArgumentError # an unknown platform
        render json: { errors: [ "Platform must be apple or google" ] }, status: :unprocessable_entity
      end

      # DELETE /api/v1/push_devices { token }
      def destroy
        @app_user.push_devices.where(token: params[:token]).destroy_all
        head :no_content
      end

      private

      def authenticate_app_user!
        header = request.headers["Authorization"].to_s
        @app_user = JwtService.verify_auth_token(header.delete_prefix("Bearer ")) if header.start_with?("Bearer ")
        return head(:unauthorized) unless @app_user

        set_current_tenant(@app_user.community)
      end
    end
  end
end
