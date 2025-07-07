# frozen_string_literal: true

# Configure how to access calendar credentials based on environment
module CalendarCredentials
  def self.credentials_io
    if ENV["CALENDAR_CONFIG_CONTENT"].present?
      # Production: Use credentials content from environment variable
      StringIO.new(ENV["CALENDAR_CONFIG_CONTENT"])
    elsif ENV["CALENDAR_CONFIG_FILE"].present?
      # Development: Use file path from environment variable
      File.open(ENV["CALENDAR_CONFIG_FILE"])
    else
      raise "Missing calendar credentials: set either CALENDAR_CONFIG_CONTENT or CALENDAR_CONFIG_FILE"
    end
  end
end
