# frozen_string_literal: true

class EmailLogInterceptor
  def self.delivering_email(message)
    community_id = message.header["X-Community-ID"]&.value&.to_i
    return unless community_id&.positive?

    mailer_info = extract_mailer_info(message)

    log = EmailLog.create!(
      community_id: community_id,
      to: Array(message.to).join(", "),
      from: Array(message.from).join(", "),
      subject: message.subject,
      mailer_class: mailer_info[:class],
      mailer_action: mailer_info[:action],
      status: "pending"
    )

    # Store log ID in message header so observer can update it
    message.header["X-Email-Log-ID"] = log.id.to_s
  rescue StandardError => e
    Rails.logger.error("EmailLogInterceptor failed to create log: #{e.message}")
  end

  def self.extract_mailer_info(message)
    mailer_class = message.header["X-Mailer"]&.value
    if mailer_class&.include?("#")
      parts = mailer_class.split("#")
      { class: parts[0], action: parts[1] }
    else
      { class: mailer_class, action: nil }
    end
  end
end
