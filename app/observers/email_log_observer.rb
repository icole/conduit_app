# frozen_string_literal: true

class EmailLogObserver
  def self.delivered_email(message)
    log_id = message.header["X-Email-Log-ID"]&.value&.to_i

    if log_id&.positive?
      # Update existing log entry created by interceptor
      update_log_status(log_id, "delivered")
    else
      # Fallback: create new log entry if interceptor didn't run
      create_log_entry(message, "delivered")
    end
  rescue StandardError => e
    Rails.logger.error("EmailLogObserver failed to log email: #{e.message}")
  end

  def self.update_log_status(log_id, status, error_message: nil)
    log = EmailLog.find_by(id: log_id)
    return unless log

    log.update!(
      status: status,
      sent_at: Time.current,
      error_message: error_message
    )
  end

  def self.create_log_entry(message, status, error_message: nil)
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
      status: status,
      sent_at: status == "delivered" ? Time.current : nil,
      error_message: error_message
    )
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
