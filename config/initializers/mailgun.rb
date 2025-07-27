# Mailgun configuration for ActionMailer
if Rails.env.production?
  require "mailgun-ruby"

  Rails.application.configure do
    # Configure mailgun for email delivery
    ActionMailer::Base.add_delivery_method :mailgun, Mail::Mailgun,
                                           api_key: ENV["MAILGUN_API_KEY"],
                                           domain: ENV["MAILGUN_DOMAIN"]
  end
end
