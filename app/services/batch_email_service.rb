# frozen_string_literal: true

# Service for sending emails in batches via Resend's Batch API
# This avoids rate limiting issues (2 req/sec on free tier) by sending
# up to 100 emails per API call.
#
# Usage:
#   service = BatchEmailService.new
#   service.add(MealMailer.meal_reminder(meal, user1))
#   service.add(MealMailer.meal_reminder(meal, user2))
#   service.deliver_all
#
class BatchEmailService
  MAX_BATCH_SIZE = 100

  def initialize
    @emails = []
  end

  # Add a Mail::Message to the batch queue
  # @param mail_message [Mail::Message] An ActionMailer message (not yet delivered)
  def add(mail_message)
    @emails << mail_message_to_resend_params(mail_message)
  end

  # Send all queued emails in batches of 100
  # @return [Array<Hash>] Array of responses from each batch
  def deliver_all
    return [] if @emails.empty?

    # Only send real emails in production
    unless Rails.env.production?
      count = @emails.size
      @emails = []
      Rails.logger.info("BatchEmailService: Skipped sending #{count} emails (not in production)")
      return [ { skipped: true, count: count } ]
    end

    responses = []
    @emails.each_slice(MAX_BATCH_SIZE) do |batch|
      response = send_batch(batch)
      responses << response
    end

    @emails = []
    responses
  end

  # Number of emails currently queued
  def size
    @emails.size
  end

  private

  def mail_message_to_resend_params(mail)
    {
      from: mail.from&.first || default_from,
      to: Array(mail.to),
      subject: mail.subject,
      html: mail.html_part&.body&.to_s || mail.body.to_s,
      text: mail.text_part&.body&.to_s
    }.compact
  end

  def send_batch(batch)
    Resend::Batch.send(batch)
  rescue Resend::Error => e
    Rails.logger.error("BatchEmailService: Failed to send batch of #{batch.size} emails: #{e.message}")
    { error: e.message, batch_size: batch.size }
  end

  def default_from
    "#{ActsAsTenant.current_tenant&.name || 'Conduit'} <noreply@conduitcoho.app>"
  end
end
