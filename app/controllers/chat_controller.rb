class ChatController < ApplicationController
  # Mobile API endpoints that use JWT auth
  MOBILE_API_ACTIONS = [ :token, :create_channel, :update_channel, :destroy_channel, :sync_channel_members ].freeze

  # Skip tenant-from-domain for mobile API endpoints - tenant will be set from authenticated user
  skip_before_action :set_tenant_from_domain, only: MOBILE_API_ACTIONS

  # Skip standard session auth for mobile API endpoints - they use JWT
  skip_before_action :authenticate_user!, only: MOBILE_API_ACTIONS
  before_action :authenticate_user!, except: [ :debug ] + MOBILE_API_ACTIONS

  # Mobile API auth - supports both JWT and session
  before_action :set_tenant_from_jwt, only: MOBILE_API_ACTIONS
  before_action :authenticate_api_or_session!, only: MOBILE_API_ACTIONS

  before_action :ensure_stream_configured, except: [ :debug, :token ]

  # Skip CSRF for API endpoints called from mobile apps
  skip_forgery_protection only: MOBILE_API_ACTIONS

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

    user = api_current_user
    respond_to do |format|
      format.json do
        render json: {
          token: generate_stream_token(user),
          user: {
            id: user.id.to_s,
            name: user.name,
            avatar: user.avatar_url,
            restricted_access: user.restricted_access
          },
          api_key: StreamChatClient.api_key,
          community_slug: user.community.slug
        }
      end
      format.any do
        render json: {
          token: generate_stream_token(user),
          user: {
            id: user.id.to_s,
            name: user.name,
            avatar: user.avatar_url,
            restricted_access: user.restricted_access
          },
          api_key: StreamChatClient.api_key,
          community_slug: user.community.slug
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
      user = api_current_user
      community = user.community

      # Create a slug from the channel name, prefixed with community slug
      base_id = channel_name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
      channel_id = "#{community.slug}-#{base_id}"

      # Get all community users and sync them to Stream
      community_users = community.users.select(:id, :name, :avatar_url, :admin)
      users_to_sync = community_users.map do |u|
        {
          id: u.id.to_s,
          name: u.name,
          image: u.avatar_url,
          role: u.admin? ? "admin" : "user"
        }
      end

      # Upsert all users to Stream (creates them if they don't exist)
      client.upsert_users(users_to_sync)

      community_user_ids = community_users.map { |u| u.id.to_s }

      # Create the channel with data
      channel = client.channel("team", channel_id: channel_id, data: {
        name: channel_name,
        members: community_user_ids,
        community_slug: community.slug
      })
      channel.create(user.id.to_s)

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
      user = api_current_user
      channel = client.channel("team", channel_id: channel_id)

      # Verify channel belongs to community by checking channel ID prefix
      community_slug = user.community.slug
      unless channel_id.start_with?("#{community_slug}-")
        render json: { error: "Channel does not belong to your community" }, status: :forbidden
        return
      end

      # Query to verify channel exists
      channel.query(user_id: user.id.to_s)

      # Update the channel name
      channel.update({ name: new_name }, user_id: user.id.to_s)

      Rails.logger.info "Renamed channel #{channel_id} to '#{new_name}'"

      render json: { success: true, channel_id: channel_id, name: new_name }
    rescue StreamChat::StreamAPIException => e
      Rails.logger.error "Failed to rename channel: #{e.message}"
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  # DELETE /chat/channels/:channel_id
  # Delete a channel (admins and channel creators)
  def destroy_channel
    channel_id = params[:channel_id]
    user = api_current_user

    unless channel_id.present?
      render json: { error: "Channel ID is required" }, status: :bad_request
      return
    end

    begin
      client = StreamChatClient.client
      channel = client.channel("team", channel_id: channel_id)

      # Verify channel belongs to community by checking channel ID prefix
      community_slug = user.community.slug
      unless channel_id.start_with?("#{community_slug}-")
        render json: { error: "Channel does not belong to your community" }, status: :forbidden
        return
      end

      # Query channel to check creator
      channel_data = channel.query(user_id: user.id.to_s)
      creator_id = channel_data.dig("channel", "created_by", "id")

      unless user.admin? || user.id.to_s == creator_id
        render json: { error: "Only admins and channel creators can delete channels" }, status: :forbidden
        return
      end

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
    user = api_current_user

    unless channel_id.present?
      render json: { error: "channel_id is required" }, status: :bad_request
      return
    end

    begin
      client = StreamChatClient.client
      channel = client.channel("team", channel_id: channel_id)

      # Query the channel to get its data
      channel_data = channel.query(user_id: user.id.to_s)
      channel_info = channel_data["channel"]

      # Verify the channel belongs to the current user's community
      channel_community_slug = channel_info["community_slug"]
      user_community_slug = user.community.slug

      if channel_community_slug != user_community_slug
        render json: { error: "Channel does not belong to your community" }, status: :forbidden
        return
      end

      # Get all users from the current community
      community_user_ids = user.community.users.pluck(:id).map(&:to_s)

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

  def generate_stream_token(user = nil)
    user ||= current_user
    # Sync user to Stream first
    sync_user_to_stream(user)

    # Ensure user is in default channels
    StreamChannelService.ensure_user_in_default_channels(user)

    # Generate token
    StreamChatClient.client.create_token(user.id.to_s)
  end

  def sync_user_to_stream(user = nil)
    user ||= current_user
    StreamChatClient.client.upsert_user({
      id: user.id.to_s,
      name: user.name,
      image: user.avatar_url,
      role: user.admin? ? "admin" : "user"
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

  def set_tenant_from_user
    return unless current_user&.community

    set_current_tenant(current_user.community)
  end

  # JWT authentication for mobile API endpoints
  def set_tenant_from_jwt
    auth_header = request.headers["Authorization"]
    return unless auth_header.present? && auth_header.start_with?("Bearer ")

    token = auth_header.split(" ").last
    decoded = JwtService.decode(token)
    return unless decoded && decoded[:community_id]

    community = Community.find_by(id: decoded[:community_id])
    set_current_tenant(community) if community
  end

  def authenticate_api_or_session!
    # Try JWT auth first (for mobile apps)
    auth_header = request.headers["Authorization"]

    if auth_header.present? && auth_header.start_with?("Bearer ")
      token = auth_header.split(" ").last
      user = JwtService.verify_auth_token(token)

      if user
        @api_current_user = user
        set_current_tenant(user.community) if user.community
        return
      end
    end

    # Fall back to session authentication
    # Must find user WITHOUT tenant scope since tenant isn't set yet
    # (set_tenant_from_domain is skipped for mobile API actions)
    if session[:user_id]
      user = ActsAsTenant.without_tenant { User.find_by(id: session[:user_id]) }
      if user
        @api_current_user = user
        set_current_tenant(user.community) if user.community
        return
      end
    end

    render json: { error: "Authentication required" }, status: :unauthorized
  end

  # Use @api_current_user for mobile API endpoints, fallback to current_user
  def api_current_user
    @api_current_user || current_user
  end
end
