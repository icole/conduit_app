# frozen_string_literal: true

class EmailLogsController < ApplicationController
  before_action :authorize_admin!

  def index
    @status_filter = params[:status]
    @email_logs = EmailLog.recent

    if @status_filter.present? && EmailLog::STATUSES.include?(@status_filter)
      @email_logs = @email_logs.where(status: @status_filter)
    end

    @email_logs = @email_logs.limit(100)

    # Counts for filter tabs
    @total_count = EmailLog.count
    @delivered_count = EmailLog.delivered.count
    @failed_count = EmailLog.failed.count
  end

  def show
    @email_log = EmailLog.find(params[:id])
  end
end
