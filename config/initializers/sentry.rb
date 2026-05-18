# frozen_string_literal: true

# Only initialize Sentry in production when DSN is provided
if Rails.env.production? && ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.breadcrumbs_logger = [ :active_support_logger ]
    config.dsn = ENV["SENTRY_DSN"]

    # Sample 10% of transactions for performance monitoring
    config.traces_sample_rate = 0.1

    # Do not send PII (cookies, user IP, request body) by default
    config.send_default_pii = false

    # Filter noisy errors before sending
    config.before_send = lambda do |event, hint|
      exception = hint[:exception]

      # Drop encoding errors from malformed bot/scanner requests
      if exception.is_a?(Encoding::CompatibilityError) ||
         exception.is_a?(Encoding::InvalidByteSequenceError) ||
         exception.is_a?(Encoding::UndefinedConversionError)
        return nil
      end

      event
    end
  end
end
