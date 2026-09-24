# frozen_string_literal: true

# Nightly check that chat usage isn't approaching the Stream plan's limit.
# Alerts once per threshold per month, so crossing 70% mails once rather than
# every night, and climbing to 90% mails again.
class StreamUsageReportJob < ApplicationJob
  queue_as :default

  def perform(limit: StreamUsageReport.plan_limit)
    report = StreamUsageReport.new(limit: limit).call

    Rails.logger.info(
      "StreamUsageReportJob: #{report[:total]} chat users this month" \
      "#{report[:percent_used] ? " (#{report[:percent_used]}% of #{report[:limit]})" : ""}; " \
      "#{report[:by_community].map { |slug, n| "#{slug}=#{n}" }.join(' ')}"
    )

    threshold = report[:threshold]
    return if threshold.nil?
    return unless CommunityMailer.notify_address
    return unless claim_alert(threshold, report[:period])

    Sentry.capture_message(
      "Stream chat usage at #{report[:percent_used]}% of the #{report[:limit]} MAU plan limit",
      level: :warning
    ) if defined?(Sentry) && Sentry.respond_to?(:capture_message)

    CommunityMailer.stream_usage_alert(report).deliver_later
  end

  private

  # One alert per threshold per month. Returns false if it was already sent.
  def claim_alert(threshold, period)
    key = "stream_usage_alert/#{period.begin.strftime('%Y-%m')}/#{threshold}"
    return false if Rails.cache.read(key)

    Rails.cache.write(key, true, expires_in: 60.days)
    true
  end
end
