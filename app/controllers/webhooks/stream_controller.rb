# frozen_string_literal: true

module Webhooks
  class StreamController < ApplicationController
    skip_before_action :set_tenant_from_domain
    skip_before_action :authenticate_user!
    skip_before_action :verify_user_belongs_to_tenant!
    skip_forgery_protection

    before_action :verify_stream_signature

    # POST /webhooks/stream
    def create
      event_type = params[:type]
      Rails.logger.info "[Stream Webhook] Received event: #{event_type}"

      case event_type
      when "channel.created"
        handle_channel_created
      else
        Rails.logger.debug "[Stream Webhook] Ignoring event type: #{event_type}"
      end

      head :ok
    end

    private

    def handle_channel_created
      channel_data = params[:channel]
      return unless channel_data

      channel_id = channel_data[:id]
      channel_type = channel_data[:type]
      channel_cid = channel_data[:cid] || "#{channel_type}:#{channel_id}"

      Rails.logger.info "[Stream Webhook] Channel created: #{channel_cid}"

      # Check if channel ID follows the expected pattern: community-slug-channel-name
      # Valid channels are created via our server endpoint and have the community slug prefix
      unless valid_channel_id?(channel_id)
        Rails.logger.warn "[Stream Webhook] Invalid channel ID format: #{channel_id}, deleting..."
        delete_invalid_channel(channel_type, channel_id)
      end
    end

    def valid_channel_id?(channel_id)
      return false if channel_id.blank?

      # Channel ID should start with a valid community slug
      Community.exists?(slug: channel_id.split("-").first)
    end

    def delete_invalid_channel(channel_type, channel_id)
      return unless StreamChatClient.configured?

      begin
        client = StreamChatClient.client
        channel = client.channel(channel_type, channel_id: channel_id)
        channel.delete

        Rails.logger.info "[Stream Webhook] Deleted invalid channel: #{channel_type}:#{channel_id}"
      rescue StreamChat::StreamAPIException => e
        Rails.logger.error "[Stream Webhook] Failed to delete channel: #{e.message}"
      end
    end

    def verify_stream_signature
      # Stream signs webhooks with the API secret
      # The signature is in the X-Signature header
      signature = request.headers["X-Signature"]

      unless signature.present?
        Rails.logger.warn "[Stream Webhook] Missing signature header"
        head :unauthorized
        return
      end

      body = request.raw_post
      expected_signature = OpenSSL::HMAC.hexdigest(
        "SHA256",
        StreamChatClient.api_secret,
        body
      )

      unless ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
        Rails.logger.warn "[Stream Webhook] Invalid signature"
        head :unauthorized
      end
    end
  end
end
