class ApplicationMailbox < ActionMailbox::Base
  # Route emails sent to our mailing list subdomain to MailingListMailbox
  # This will capture emails like community@lists.example.com, announcements@lists.example.com, etc.
  subdomain = Rails.application.credentials.mailing_list_subdomain || ENV["MAILING_LIST_SUBDOMAIN"] || "lists"
  base_domain = Rails.application.credentials.mailing_list_domain || ENV["MAILING_LIST_DOMAIN"] || "example.com"

  routing(/@#{Regexp.escape("#{subdomain}.#{base_domain}")}$/i => :mailing_list)
end
