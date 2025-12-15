# SMTP configuration for ActionMailer (Namecheap PrivateEmail)
if Rails.env.production?
  Rails.application.configure do
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: "mail.privateemail.com",
      port: 587,
      domain: "crowwoods.com",
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
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
