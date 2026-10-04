require "test_helper"

# Email logs keep recipients' addresses, which outlive their accounts; the
# privacy policy promises personal data is gone within 30 days of deletion
class EmailLogRetentionJobTest < ActiveJob::TestCase
  def log(community, sent:)
    ActsAsTenant.with_tenant(community) do
      EmailLog.create!(to: "member@example.com", subject: "Dinner tonight", status: "delivered", created_at: sent, sent_at: sent)
    end
  end

  test "deletes every community's email logs older than 30 days, keeps the rest" do
    old_here = log(communities(:crow_woods), sent: 31.days.ago)
    old_there = log(communities(:other_community), sent: 45.days.ago)
    recent = log(communities(:crow_woods), sent: 29.days.ago)

    EmailLogRetentionJob.perform_now

    remaining = ActsAsTenant.without_tenant { EmailLog.where(id: [ old_here, old_there, recent ]).pluck(:id) }
    assert_equal [ recent.id ], remaining
  end

  test "runs every day in production" do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig("production", "email_log_retention")
    assert_equal "EmailLogRetentionJob", schedule&.dig("class")
  end
end
