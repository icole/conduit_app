# frozen_string_literal: true

class CalendarService
  def initialize
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = authorize_service_account
  end

  private

  def authorize_service_account
    # Option 1: Direct file path
    Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: CalendarCredentials.credentials_io,
      scope: [ "https://www.googleapis.com/auth/calendar" ]
    )
  end
end
