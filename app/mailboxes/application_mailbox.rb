class ApplicationMailbox < ActionMailbox::Base
  # Mailing lists are now handled directly by Mailgun
  # No routing needed as emails go directly through Mailgun's mailing list service
end
