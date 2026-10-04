require "test_helper"
require "fugit"
require_relative "../support/fake_backup_bucket"

class NightlyBackupJobTest < ActiveJob::TestCase
  test "uploads tonight's encrypted database dump and syncs the uploaded files" do
    bucket = FakeBackupBucket.new
    travel_to Time.utc(2026, 10, 4, 10, 15) do
      Dir.mktmpdir do |root|
        File.write(File.join(root, "photo"), "a photo")
        NightlyBackupJob.perform_now(bucket: bucket, passphrase: "test-passphrase", storage_root: root)
      end
    end

    assert_includes bucket.uploads, "db/conduit_app-2026-10-04T1015Z.dump.enc"
    assert_includes bucket.uploads, "files/photo"
  end

  test "does nothing where no backup bucket is configured" do
    assert_nil NightlyBackupJob.perform_now
  end

  # When Solid Queue next runs the backup. As SolidQueue::RecurringTask#next_time
  # does, a schedule without a zone runs in SolidQueue.time_zone (the app's).
  def solid_queue_next_run
    recurring = YAML.load(ERB.new(Rails.root.join("config/recurring.yml").read).result, aliases: true)
    cron = Fugit.parse_cron(recurring.dig("production", "nightly_backup", "schedule"))
    cron = Fugit.parse_cron("#{cron.to_cron_s} #{SolidQueue.time_zone}") if cron.zone.nil? && SolidQueue.time_zone.present?
    cron.next_time.to_t.utc
  end

  # Comparing the crontab strings passed while Solid Queue read them in the
  # app's time zone and Sentry in UTC: the backup ran at 10:15 Pacific, and
  # Sentry reported 10:15 UTC as missed
  test "runs when Sentry's monitor expects it, so a missed night alerts at the right time" do
    monitor = NightlyBackupJob.sentry_monitor_config
    sentry_cron = Fugit.parse_cron("#{monitor.schedule.value} #{monitor.timezone || 'UTC'}")

    travel_to Time.utc(2026, 10, 4, 12) do
      assert_equal sentry_cron.next_time.to_t.utc, solid_queue_next_run
    end
  end

  test "runs in the small hours, Pacific" do
    travel_to Time.utc(2026, 10, 4, 12) do
      assert_includes 1..4, solid_queue_next_run.in_time_zone("America/Los_Angeles").hour
    end
  end
end
