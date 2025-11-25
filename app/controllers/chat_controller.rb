# frozen_string_literal: true

class ChatController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_stream_configured

  def index
    # Main chat interface for web testing
    # This will be replaced by Hotwire Native for mobile
    @stream_token = generate_stream_token
    @current_user_data = {
      id: current_user.id.to_s,
      name: current_user.name,
      avatar: current_user.avatar_url
    }
  end

  def token
    # API endpoint for mobile app to get Stream token
    render json: {
      token: generate_stream_token,
      user: {
        id: current_user.id.to_s,
        name: current_user.name,
        avatar: current_user.avatar_url
      },
      api_key: StreamChatClient.api_key
    }
  end

  def channels
    # API endpoint to get list of available channels
    # These are the HOA community channels
    render json: {
      channels: [
        { id: 'general', name: 'General Chat', type: 'team' },
        { id: 'building-a', name: 'Building A', type: 'team' },
        { id: 'building-b', name: 'Building B', type: 'team' },
        { id: 'pool', name: 'Pool Area', type: 'team' },
        { id: 'maintenance', name: 'Maintenance', type: 'team' },
        { id: 'announcements', name: 'Announcements', type: 'announcement' },
        { id: 'board', name: 'HOA Board', type: 'team', members_only: true }
      ]
    }
  end

  private

  def generate_stream_token
    # Ensure user exists in Stream
    sync_user_to_stream

    # Generate token for the user
    StreamChatClient.client.create_token(current_user.id.to_s)
  end

  def sync_user_to_stream
    # Create or update user in Stream
    StreamChatClient.client.upsert_user({
      id: current_user.id.to_s,
      name: current_user.name,
      image: current_user.avatar_url,
      role: current_user.admin? ? 'admin' : 'user'
    })
  rescue StreamChat::StreamAPIException => e
    Rails.logger.error "Failed to sync user to Stream: #{e.message}"
    raise e
  end

  def ensure_stream_configured
    unless StreamChatClient.configured?
      redirect_to root_path, alert: "Chat is not configured. Please add Stream API credentials."
    end
  end
end