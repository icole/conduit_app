# frozen_string_literal: true

require 'stream-chat'

# Stream Chat configuration wrapper
# You'll need to create a free Stream account at https://getstream.io/
# and get your API Key and Secret from the Dashboard
module StreamChatClient
  class << self
    def client
      @client ||= StreamChat::Client.new(api_key, api_secret)
    end

    def configured?
      api_key.present? && api_secret.present?
    end

    def api_key
      ENV['STREAM_API_KEY'] || Rails.application.credentials.dig(:stream, :api_key)
    end

    def api_secret
      ENV['STREAM_API_SECRET'] || Rails.application.credentials.dig(:stream, :api_secret)
    end
  end
end