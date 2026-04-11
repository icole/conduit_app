# frozen_string_literal: true

class CalendarService
  def initialize
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = authorize_service_account
  end

  private

  def authorize_service_account
    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: CalendarCredentials.credentials_io,
      scope: [ "https://www.googleapis.com/auth/calendar" ]
    )
    credentials.sub = ENV["GOOGLE_IMPERSONATE_EMAIL"]
    credentials
  end
end
