# frozen_string_literal: true

# Email configuration using Resend
# Only send real emails in production to avoid accidental sends during development
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
else
  # Development and test environments: don't send real emails
  Rails.application.configure do
    config.action_mailer.delivery_method = :test
    config.action_mailer.raise_delivery_errors = true
  end

  Rails.logger.info "[EMAIL CONFIG] Using test delivery method (emails will not be sent)"
end
