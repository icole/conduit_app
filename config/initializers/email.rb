# Gmail SMTP configuration for ActionMailer
if Rails.env.production?
  Rails.application.configure do
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: "smtp.gmail.com",
      port: 587,
      domain: "crowwoods.com",
      user_name: ENV["GMAIL_USERNAME"],
      password: ENV["GMAIL_APP_PASSWORD"],
      authentication: :plain,
      enable_starttls_auto: true
    }
    config.action_mailer.raise_delivery_errors = true
  end
elsif Rails.env.development?
  Rails.application.configure do
    # Use letter_opener or just log emails in development
    config.action_mailer.delivery_method = :test
    config.action_mailer.raise_delivery_errors = true
  end
end
