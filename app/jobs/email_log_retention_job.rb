# Deletes email logs once they're 30 days old, across every community. They
# hold recipients' addresses, and the privacy policy promises personal data is
# gone within 30 days of an account's deletion.
class EmailLogRetentionJob < ApplicationJob
  queue_as :default

  KEEP_FOR = 30.days

  def perform
    ActsAsTenant.without_tenant do
      EmailLog.where(created_at: ...KEEP_FOR.ago).in_batches.delete_all
    end
  end
end
