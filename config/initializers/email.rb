# frozen_string_literal: true

# Email configuration using Resend
if Rails.env.production?
  resend_api_key = ENV["RESEND_API_KEY"]

  if resend_api_key.blank?
    Rails.logger.warn "[EMAIL CONFIG] RESEND_API_KEY environment variable is not set. Email delivery will fail."
  else
    Resend.api_key = resend_api_key
  end

  Rails.application.configure do
    config.action_mailer.delivery_method = :resend
    config.action_mailer.raise_delivery_errors = true
  end
elsif Rails.env.development?
  # Check if Resend API key is available for dev testing
  if ENV["RESEND_API_KEY"].present?
    Resend.api_key = ENV["RESEND_API_KEY"]
    Rails.application.configure do
      config.action_mailer.delivery_method = :resend
      config.action_mailer.raise_delivery_errors = true
    end
  else
    Rails.application.configure do
      # Use test delivery method in development without API key
      config.action_mailer.delivery_method = :test
      config.action_mailer.raise_delivery_errors = true
    end
  end
end
