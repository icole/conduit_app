class MailingListMailbox < ApplicationMailbox
  before_processing :ensure_valid_list

  def process
    # Extract list name from the first recipient email address
    recipient_email = extract_recipient_email
    return unless recipient_email

    list_name = recipient_email.split("@").first
    mailing_list = MailingList.find_by(name: list_name, active: true)

    if mailing_list
      # Forward email to all list members except the sender
      sender_email = mail.from.first.downcase

      user_count = 0
      mailing_list.users.each do |user|
        # Don't send email back to the original sender
        next if user.email.downcase == sender_email

        MailingListMailer.forward_email(user, mail, mailing_list).deliver_now
        user_count += 1
      end

      Rails.logger.info "Forwarded email to #{mailing_list.name} list (#{user_count} recipients)"
    else
      Rails.logger.warn "Received email for unknown or inactive mailing list: #{list_name}"
    end
  end

  private

  def ensure_valid_list
    recipient_email = extract_recipient_email

    unless recipient_email
      Rails.logger.error "Could not extract recipient email from inbound message"
      return false
    end

    unless recipient_email.end_with?("@#{mailing_list_domain}")
      Rails.logger.error "Email not for our mailing list domain: #{recipient_email}"
      return false
    end

    true
  end

  def extract_recipient_email
    # Check 'to' field first, then 'cc', then 'bcc'
    mail.to&.first || mail.cc&.first || mail.bcc&.first
  end

  def mailing_list_domain
    subdomain = Rails.application.credentials.mailing_list_subdomain || ENV["MAILING_LIST_SUBDOMAIN"] || "lists"
    base_domain = Rails.application.credentials.mailing_list_domain || ENV["MAILING_LIST_DOMAIN"] || "example.com"
    "#{subdomain}.#{base_domain}"
  end
end
