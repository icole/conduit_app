# frozen_string_literal: true

class CalendarFeedsController < ApplicationController
  # Calendar apps fetch the feed without a session: the unguessable
  # per-member token in the URL is the credential, looked up within the
  # community the domain names
  skip_before_action :authenticate_user!

  def show
    user = User.find_by(calendar_feed_token: params[:token])

    # The member's own community's calendar; a community without one has no feed
    calendar_id = current_community&.google_calendar_id
    unless user && calendar_id.present?
      head :not_found
      return
    end

    service = GoogleCalendarApiService.from_service_account_with_acl_scope
    result = service.get_events(
      calendar_id: calendar_id,
      time_min: 1.month.ago.beginning_of_day,
      time_max: 3.months.from_now.end_of_day,
      max_results: 2500
    )

    cal = Icalendar::Calendar.new
    cal.prodid = "-//Conduit//#{current_community.name}//EN"
    cal.x_wr_calname = current_community.name
    cal.append_custom_property("X-WR-TIMEZONE", current_community.time_zone)

    if result[:status] == :success
      result[:events].each do |event|
        cal.event do |e|
          e.uid = "#{event[:id]}@#{current_community.domain}"
          e.summary = event[:summary]
          e.description = event[:description] if event[:description].present?
          e.location = event[:location] if event[:location].present?

          e.ip_class = "PUBLIC"
          e.transp = "TRANSPARENT"

          if event[:all_day]
            e.dtstart = Icalendar::Values::Date.new(event[:start_time].to_date)
            e.dtend = Icalendar::Values::Date.new(event[:end_time].to_date)
          else
            e.dtstart = Icalendar::Values::DateTime.new(event[:start_time].utc, "tzid" => "UTC")
            e.dtend = Icalendar::Values::DateTime.new(event[:end_time].utc, "tzid" => "UTC")
          end
        end
      end
    end

    response.headers["Content-Type"] = "text/calendar; charset=utf-8"
    render plain: cal.to_ical
  end
end
