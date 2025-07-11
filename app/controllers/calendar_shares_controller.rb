# frozen_string_literal: true

class CalendarSharesController < ApplicationController
  before_action :authenticate_user!

  # Share a calendar with the current user
  def create
    calendar_id = params[:calendar_id] || ENV["GOOGLE_CALENDAR_ID"]

    Rails.logger.info("Attempting to share calendar '#{calendar_id}' with user: #{current_user.email}")

    # Verify the required configuration is available
    unless ENV["GOOGLE_CALENDAR_ID"].present?
      Rails.logger.error("Missing GOOGLE_CALENDAR_ID environment variable")
      return redirect_back(fallback_location: root_path, alert: "Calendar configuration incomplete. Please contact the administrator.")
    end

    # Check if calendar is already shared with this user
    if CalendarShare.calendar_shared_with_user?(calendar_id, current_user)
      Rails.logger.info("Calendar '#{calendar_id}' already shared with user: #{current_user.email}")
      return redirect_back(
        fallback_location: root_path,
        notice: "You already have access to this calendar."
      )
    end

    # Make sure we have calendar credentials available
    begin
      # Get service with write access to calendar
      service = GoogleCalendarApiService.from_service_account_with_acl_scope

      # Attempt to share the calendar with the current user
      result = service.share_calendar_with_user(
        calendar_id: calendar_id,
        email: current_user.email,
        role: "reader"
      )

      Rails.logger.info("Calendar sharing result: #{result.inspect}")

      if result[:status] == :success
        # Record the successful calendar share
        CalendarShare.create!(
          user: current_user,
          calendar_id: calendar_id,
          shared_at: Time.current
        )

        session[:shared_calendar_id] = calendar_id
        redirect_to success_calendar_shares_path
      else
        redirect_back(
          fallback_location: root_path,
          alert: "Could not share calendar: #{result[:error]}"
        )
      end
    rescue StandardError => e
      Rails.logger.error("Calendar sharing error: #{e.message}\n#{e.backtrace.join("\n")}")
      redirect_back(
        fallback_location: root_path,
        alert: "An error occurred while trying to share the calendar. Please try again later."
      )
    end
  end

  # Show success page after calendar has been shared
  def success
    @calendar_id = session.delete(:shared_calendar_id) || ENV["GOOGLE_CALENDAR_ID"]
  end
end
