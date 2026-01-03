# frozen_string_literal: true

class EmailDeliveryJob < ActionMailer::MailDeliveryJob
  # Catch delivery failures and log them
  rescue_from StandardError do |exception|
    # Extract the email log ID from the mail message if available
    mail_message = @mail_message || extract_mail_message

    if mail_message
      log_id = mail_message.header["X-Email-Log-ID"]&.value&.to_i
      if log_id&.positive?
        EmailLog.where(id: log_id).update_all(
          status: "failed",
          error_message: "#{exception.class}: #{exception.message}",
          sent_at: Time.current
        )
      end
    end

    # Re-raise so the job fails and can be retried if configured
    raise exception
  end

  private

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
