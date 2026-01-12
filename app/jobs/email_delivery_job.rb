# frozen_string_literal: true

class EmailDeliveryJob < ActionMailer::MailDeliveryJob
  # Catch delivery failures and log them
  rescue_from StandardError do |exception|
    # Extract the email log ID from the mail message if available
    mail_message = @mail_message || extract_mail_message

    error_message = build_error_message(exception)

    if mail_message
      log_id = mail_message.header["X-Email-Log-ID"]&.value&.to_i
      if log_id&.positive?
        EmailLog.where(id: log_id).update_all(
          status: "failed",
          error_message: error_message,
          sent_at: Time.current
        )
      end
    end

    # Log additional context for SMTP authentication errors
    if exception.is_a?(Net::SMTPAuthenticationError)
      Rails.logger.error "[EMAIL DELIVERY] SMTP Authentication failed. " \
                         "Check SMTP_USERNAME and SMTP_PASSWORD environment variables. " \
                         "Error: #{exception.message}"
    end

    # Re-raise so the job fails and can be retried if configured
    raise exception
  end

  private

  def build_error_message(exception)
    base_message = "#{exception.class}: #{exception.message}"

    # Add helpful context for common SMTP errors
    case exception
    when Net::SMTPAuthenticationError
      "#{base_message} - Verify SMTP credentials (SMTP_USERNAME/SMTP_PASSWORD) are correct and the account is not locked"
    when Net::SMTPServerBusy
      "#{base_message} - SMTP server is busy, will retry"
    when Net::OpenTimeout, Net::ReadTimeout
      "#{base_message} - Connection to SMTP server timed out"
    else
      base_message
    end
  end

  def extract_mail_message
    # Try to reconstruct the mail message from job arguments
    # Arguments are: [mailer_class, mailer_action, delivery_method, args]
    mailer_class, mailer_action, _delivery_method, args = arguments
    return nil unless mailer_class && mailer_action

    mailer = mailer_class.constantize
    mailer.public_send(mailer_action, *args).message
  rescue StandardError
    nil
  end
end
