# frozen_string_literal: true

require "stream-chat"

# Stream Chat configuration wrapper
# You'll need to create a free Stream account at https://getstream.io/
# and get your API Key and Secret from the Dashboard
module StreamChatClient
  # Chat tokens expire after this (CON-80). Clients with a token provider (the
  # web chat, and app versions that ask for expiring tokens) fetch a new one
  # when it runs out, so a short life costs nothing.
  TOKEN_TTL = 1.hour

  class << self
    # A Stream token for +user_id+. Expiring unless the caller is an app
    # installed before apps could fetch a new token, which would otherwise lose
    # chat once its token ran out.
    def token_for(user_id, expiring:)
      return client.create_token(user_id.to_s) unless expiring

      client.create_token(user_id.to_s, (Time.current + TOKEN_TTL).to_i)
    end

    def client
      @client ||= StreamChat::Client.new(api_key, api_secret)
    end

    def configured?
      api_key.present? && api_secret.present?
    end

    def api_key
      ENV["STREAM_API_KEY"] || Rails.application.credentials.dig(:stream, :api_key)
    end

    def api_secret
      ENV["STREAM_API_SECRET"] || Rails.application.credentials.dig(:stream, :api_secret)
    end
  end
end
