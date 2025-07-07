# frozen_string_literal: true

class CalendarEventsController < ApplicationController
  before_action only: [ :index, :show ]

  def index
    auth = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: CalendarCredentials.credentials_io,
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
    service = GoogleCalendarApiService.new(auth)
    @calendar_events = service.get_events
  end

  def show
  end
end
