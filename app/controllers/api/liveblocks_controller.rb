module Api
  class LiveblocksController < ApplicationController
    before_action :authenticate_user!
    skip_before_action :verify_authenticity_token

    # GET /api/liveblocks/users
    # Resolves user IDs to user info for Liveblocks comments
    def users
      user_ids = params[:userIds]

      unless user_ids.present?
        render json: [], status: :ok
        return
      end

      # Parse user IDs (they come as strings)
      ids = user_ids.is_a?(Array) ? user_ids.map(&:to_i) : [ user_ids.to_i ]

      users = User.where(id: ids).index_by(&:id)

      # Return users in the same order as requested
      result = ids.map do |id|
        user = users[id]
        if user
          {
            name: user.name,
            avatar: user.avatar_url,
            color: user_color(id)
          }
        else
          { name: "Unknown User" }
        end
      end

      render json: result, status: :ok
    end

    # POST /api/liveblocks/auth
    # Authenticates the user for Liveblocks and returns a token
    def auth
      # Get room ID from request (format: "document:123")
      room = params[:room]

      unless room.present?
        render json: { error: "Room is required" }, status: :bad_request
        return
      end

      # Extract document ID from room name
      document_id = room.split(":").last.to_i

      # Verify user has access to this document
      document = Document.find_by(id: document_id)
      unless document
        render json: { error: "Document not found" }, status: :not_found
        return
      end

      # Build Liveblocks session
      response = authorize_liveblocks(room)

      if response[:status] == :success
        render json: response[:body], status: :ok
      else
        render json: { error: response[:error] }, status: :internal_server_error
      end
    end

    private

    def authorize_liveblocks(room)
      secret_key = ENV["LIVEBLOCKS_SECRET_KEY"]

      unless secret_key.present?
        Rails.logger.error("LIVEBLOCKS_SECRET_KEY is not configured")
        return { status: :error, error: "Liveblocks not configured" }
      end

      # Liveblocks authorize-user endpoint (access token approach)
      uri = URI("https://api.liveblocks.io/v2/authorize-user")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      # Use system CA certificates
      http.ca_file = ENV["SSL_CERT_FILE"] if ENV["SSL_CERT_FILE"]
      http.cert_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{secret_key}"
      request["Content-Type"] = "application/json"

      # User info and permissions to include in the token
      request.body = {
        userId: current_user.id.to_s,
        userInfo: {
          name: current_user.name,
          avatar: current_user.avatar_url,
          color: user_color(current_user.id)
        },
        permissions: {
          room => [ "room:write" ]
        }
      }.to_json

      response = http.request(request)

      if response.code.to_i == 200 || response.code.to_i == 201
        { status: :success, body: JSON.parse(response.body) }
      else
        Rails.logger.error("Liveblocks auth failed: #{response.code} - #{response.body}")
        { status: :error, error: "Authentication failed" }
      end
    rescue StandardError => e
      Rails.logger.error("Liveblocks auth error: #{e.message}")
      { status: :error, error: e.message }
    end

    # Generate a consistent color for each user
    def user_color(user_id)
      colors = %w[
        #E57373 #F06292 #BA68C8 #9575CD #7986CB
        #64B5F6 #4FC3F7 #4DD0E1 #4DB6AC #81C784
        #AED581 #DCE775 #FFD54F #FFB74D #FF8A65
      ]
      colors[user_id % colors.length]
    end
  end
end
