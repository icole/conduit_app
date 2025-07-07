# frozen_string_literal: true
require 'base64'

# Configure how to access calendar credentials based on environment
module CalendarCredentials
  def self.credentials_io
    if ENV["CALENDAR_CONFIG_CONTENT"].present?
      # Production: Use credentials content from environment variable
      # Decode the Base64 encoded content before returning
      begin
        decoded_content = Base64.strict_decode64(ENV["CALENDAR_CONFIG_CONTENT"])
        StringIO.new(decoded_content)
      rescue StandardError => e
        Rails.logger.error("Failed to decode calendar credentials: #{e.message}")
        raise "Invalid calendar credentials format: #{e.message}"
      end
    elsif ENV["CALENDAR_CONFIG_FILE"].present?
      # Development: Use file path from environment variable
      File.open(ENV["CALENDAR_CONFIG_FILE"])
    else
      raise "Missing calendar credentials: set either CALENDAR_CONFIG_CONTENT or CALENDAR_CONFIG_FILE"
    end
  end
end
