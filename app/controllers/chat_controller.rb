class ChatController < ApplicationController
  before_action :authenticate_user!, except: [ :debug ]
  before_action :ensure_stream_configured, except: [ :debug, :token ]

  # GET /chat
  def index
    Rails.logger.info "ChatController#index - user_id: #{session[:user_id]}, current_user: #{current_user&.id}, turbo_native: #{turbo_native_app?}, user_agent: #{request.user_agent}"

    if turbo_native_app?
      # For iOS app, show a page that will trigger native chat
      render :native_prompt, layout: "turbo_native"
    else
      # For web, show embedded chat interface
      @stream_token = generate_stream_token
      @user_data = {
        id: current_user.id.to_s,
        name: current_user.name,
        avatar: current_user.avatar_url
      }
      render :index, layout: "application"
    end
  end

  # GET /chat/token
  # API endpoint for mobile app to get Stream token
  def token
    unless StreamChatClient.configured?
      render json: {
        error: "Stream Chat is not configured",
        configured: false
      }, status: :service_unavailable
      return
    end

    respond_to do |format|
      format.json do
        render json: {
          token: generate_stream_token,
          user: {
            id: current_user.id.to_s,
            name: current_user.name,
            avatar: current_user.avatar_url,
            restricted_access: current_user.restricted_access
          },
          api_key: StreamChatClient.api_key,
          community_slug: current_user.community.slug
        }
      end
      format.any do
        render json: {
          token: generate_stream_token,
          user: {
            id: current_user.id.to_s,
            name: current_user.name,
            avatar: current_user.avatar_url,
            restricted_access: current_user.restricted_access
          },
          api_key: StreamChatClient.api_key,
          community_slug: current_user.community.slug
        }
      end
    end
  end

  # GET /chat/test_native
  # Test page to verify Turbo Native detection
  def test_native
    render layout: turbo_native_app? ? "turbo_native" : "application"
  end

  # POST /chat/channels
  # Create a new channel with all community members
  def create_channel
    channel_name = params[:name]&.strip

    unless channel_name.present?
      render json: { error: "Channel name is required" }, status: :bad_request
      return
    end

    begin
      client = StreamChatClient.client
      community = current_user.community

      # Create a slug from the channel name, prefixed with community slug
      base_id = channel_name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
      channel_id = "#{community.slug}-#{base_id}"

      # Get all community users and sync them to Stream
      community_users = community.users.select(:id, :name, :avatar_url, :admin)
      users_to_sync = community_users.map do |user|
        {
          id: user.id.to_s,
          name: user.name,
          image: user.avatar_url,
          role: user.admin? ? "admin" : "user"
        }
      end

      # Upsert all users to Stream (creates them if they don't exist)
      client.upsert_users(users_to_sync)

      community_user_ids = community_users.map { |u| u.id.to_s }

      # Create the channel with data
      channel = client.channel("team", channel_id: channel_id, data: {
        name: channel_name,
        members: community_user_ids
      })
      channel.create(current_user.id.to_s)

      Rails.logger.info "Created channel #{channel_id} with #{community_user_ids.length} members"

      render json: {
        success: true,
        channel_id: channel_id,
        name: channel_name,
        members_count: community_user_ids.length
      }
    rescue StreamChat::StreamAPIException => e
      Rails.logger.error "Failed to create channel: #{e.message}"
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error "Error creating channel: #{e.message}"
      render json: { error: "Failed to create channel" }, status: :internal_server_error
    end
  end

  # PATCH /chat/channels/:channel_id
  # Rename a channel (any community member)
  def update_channel
    channel_id = params[:channel_id]
    new_name = params[:name]&.strip

    unless channel_id.present? && new_name.present?
      render json: { error: "Channel ID and name are required" }, status: :bad_request
      return
    end

    begin
      client = StreamChatClient.client
      channel = client.channel("team", channel_id: channel_id)

      # Verify channel belongs to community by checking channel ID prefix
      community_slug = current_user.community.slug
      unless channel_id.start_with?("#{community_slug}-")
        render json: { error: "Channel does not belong to your community" }, status: :forbidden
        return
      end

      # Query to verify channel exists
      channel.query(user_id: current_user.id.to_s)

      # Update the channel name
      channel.update({ name: new_name }, user_id: current_user.id.to_s)

      Rails.logger.info "Renamed channel #{channel_id} to '#{new_name}'"

      render json: { success: true, channel_id: channel_id, name: new_name }
    rescue StreamChat::StreamAPIException => e
      Rails.logger.error "Failed to rename channel: #{e.message}"
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  # DELETE /chat/channels/:channel_id
  # Delete a channel (admin only)
  def destroy_channel
    channel_id = params[:channel_id]

    unless current_user.admin?
      render json: { error: "Only admins can delete channels" }, status: :forbidden
      return
    end

    unless channel_id.present?
      render json: { error: "Channel ID is required" }, status: :bad_request
      return
    end

    begin
      client = StreamChatClient.client
      channel = client.channel("team", channel_id: channel_id)

      # Verify channel belongs to community by checking channel ID prefix
      community_slug = current_user.community.slug
      unless channel_id.start_with?("#{community_slug}-")
        render json: { error: "Channel does not belong to your community" }, status: :forbidden
        return
      end

      # Query to verify channel exists
      channel.query(user_id: current_user.id.to_s)

      # Delete the channel
      channel.delete

      Rails.logger.info "Deleted channel #{channel_id}"

      render json: { success: true, channel_id: channel_id }
    rescue StreamChat::StreamAPIException => e
      Rails.logger.error "Failed to delete channel: #{e.message}"
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  # POST /chat/channels/:channel_id/sync_members
  # Add all community members to a newly created channel
  def sync_channel_members
    channel_id = params[:channel_id]

    unless channel_id.present?
      render json: { error: "channel_id is required" }, status: :bad_request
      return
    end

    begin
      client = StreamChatClient.client
      channel = client.channel("team", channel_id: channel_id)

      # Query the channel to get its data
      channel_data = channel.query(user_id: current_user.id.to_s)
      channel_info = channel_data["channel"]

      # Verify the channel belongs to the current user's community
      channel_community_slug = channel_info["community_slug"]
      user_community_slug = current_user.community.slug

      if channel_community_slug != user_community_slug
        render json: { error: "Channel does not belong to your community" }, status: :forbidden
        return
      end

      # Get all users from the current community
      community_user_ids = current_user.community.users.pluck(:id).map(&:to_s)

      # Add all community members to the channel
      channel.add_members(community_user_ids)

      Rails.logger.info "Added #{community_user_ids.length} members to channel #{channel_id}"

      render json: {
        success: true,
        channel_id: channel_id,
        members_added: community_user_ids.length
      }
    rescue StreamChat::StreamAPIException => e
      Rails.logger.error "Failed to sync channel members: #{e.message}"
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error "Error syncing channel members: #{e.message}"
      render json: { error: "Failed to sync members" }, status: :internal_server_error
    end
  end

  # GET /chat/debug
  # Debug page to check Stream configuration
  def debug
    render json: {
      stream_configured: StreamChatClient.configured?,
      api_key_present: ENV["STREAM_API_KEY"].present?,
      api_secret_present: ENV["STREAM_API_SECRET"].present?,
      turbo_native_app: turbo_native_app?,
      user_agent: request.user_agent,
      authenticated: user_signed_in?,
      user_id: current_user&.id
    }
  end

  private

  def generate_stream_token
    # Sync user to Stream first
    sync_user_to_stream

    # Ensure user is in default channels
    StreamChannelService.ensure_user_in_default_channels(current_user)

    # Generate token
    StreamChatClient.client.create_token(current_user.id.to_s)
  end

  def sync_user_to_stream
    StreamChatClient.client.upsert_user({
      id: current_user.id.to_s,
      name: current_user.name,
      image: current_user.avatar_url,
      role: current_user.admin? ? "admin" : "user"
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
