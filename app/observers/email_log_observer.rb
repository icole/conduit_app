# frozen_string_literal: true

class EmailLogObserver
  def self.delivered_email(message)
    community_id = message.header["X-Community-ID"]&.value&.to_i
    return unless community_id&.positive?

    mailer_info = extract_mailer_info(message)

    EmailLog.create!(
      community_id: community_id,
      to: Array(message.to).join(", "),
      from: Array(message.from).join(", "),
      subject: message.subject,
      mailer_class: mailer_info[:class],
      mailer_action: mailer_info[:action],
      status: "delivered",
      sent_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("EmailLogObserver failed to log email: #{e.message}")
  end

  def self.extract_mailer_info(message)
    # ActionMailer adds X-Mailer-Class and X-Mailer-Action headers
    mailer_class = message.header["X-Mailer"]&.value
    if mailer_class&.include?("#")
      parts = mailer_class.split("#")
      { class: parts[0], action: parts[1] }
    else
      { class: mailer_class, action: nil }
    end
  end
end
