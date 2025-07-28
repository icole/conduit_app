# Mailgun configuration for ActionMailer
if Rails.env.production?
  require "mailgun-ruby"

  Rails.application.configure do
    # Configure SMTP delivery using Mailgun's SMTP service
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: "smtp.mailgun.org",
      port: 587,
      domain: ENV["MAILGUN_DOMAIN"],
      user_name: "postmaster@#{ENV['MAILGUN_DOMAIN']}",
      password: ENV["MAILGUN_API_KEY"],
      authentication: :plain,
      enable_starttls_auto: true
    }
  end
end
