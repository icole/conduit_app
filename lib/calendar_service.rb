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
      json_key_io: File.open('wide-gamma-462206-r8-823649cf4ac3.json'),
      scope: ['https://www.googleapis.com/auth/calendar']
    )
  end
end