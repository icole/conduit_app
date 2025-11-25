# Mailgun configuration for ActionMailer
if Rails.env.production? || Rails.env.development?
  Rails.application.configure do
    # Configure SMTP delivery using Mailgun's SMTP service
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: "smtp.mailgun.org",
      port: 587,
      domain: ENV["MAILGUN_DOMAIN"],
      user_name: ENV["MAILGUN_SMTP_USERNAME"],
      password: ENV["MAILGUN_SMTP_PASSWORD"],
      authentication: :plain,
      enable_starttls_auto: true
    }

    # Enable delivery errors in development
    config.action_mailer.raise_delivery_errors = true if Rails.env.development?
  end
end
