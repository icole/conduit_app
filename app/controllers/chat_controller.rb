class ChatController < ApplicationController
  include TurboNative

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
          api_key: StreamChatClient.api_key
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
          api_key: StreamChatClient.api_key
        }
      end
    end
  end

  # GET /chat/test_native
  # Test page to verify Turbo Native detection
  def test_native
    render layout: turbo_native_app? ? "turbo_native" : "application"
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
