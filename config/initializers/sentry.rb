# frozen_string_literal: true

# Only initialize Sentry in production when DSN is provided
if Rails.env.production? && ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.breadcrumbs_logger = [ :active_support_logger ]
    config.dsn = ENV["SENTRY_DSN"]
    config.traces_sample_rate = 1.0
  end
end
