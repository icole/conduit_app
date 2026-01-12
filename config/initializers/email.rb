# SMTP configuration for ActionMailer (Namecheap PrivateEmail)
if Rails.env.production?
  # Validate SMTP credentials are present at boot time
  smtp_username = ENV["SMTP_USERNAME"]
  smtp_password = ENV["SMTP_PASSWORD"]

  if smtp_username.blank?
    Rails.logger.warn "[EMAIL CONFIG] SMTP_USERNAME environment variable is not set. Email delivery will fail."
  end

  if smtp_password.blank?
    Rails.logger.warn "[EMAIL CONFIG] SMTP_PASSWORD environment variable is not set. Email delivery will fail."
  end

  Rails.application.configure do
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: "mail.privateemail.com",
      port: 587,
      domain: "crowwoods.com",
      user_name: smtp_username,
      password: smtp_password,
      authentication: :login,
      enable_starttls_auto: true,
      open_timeout: 10,
      read_timeout: 10
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
