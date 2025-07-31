# ActionMailbox configuration
Rails.application.configure do
  # Configure Mailgun signing key for request validation
  config.action_mailbox.mailgun_signing_key = ENV["MAILGUN_INGRESS_SIGNING_KEY"]
end
