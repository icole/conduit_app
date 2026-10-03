require "test_helper"
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

  test "runs on the schedule Sentry's monitor expects, so a missed night alerts at the right time" do
    recurring = YAML.load(ERB.new(Rails.root.join("config/recurring.yml").read).result, aliases: true)
    assert_equal NightlyBackupJob::SCHEDULE, recurring.dig("production", "nightly_backup", "schedule")
  end
end
