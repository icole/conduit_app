# Every night: an encrypted dump of the main database, then a sync of the
# uploaded files, to the backups bucket (CON-31). Sentry's cron monitor
# alerts when a night fails or doesn't run. Does nothing where no bucket is
# configured (development, test).
class NightlyBackupJob < ApplicationJob
  include Sentry::Cron::MonitorCheckIns

  # 3:15am Pacific, as in config/recurring.yml. The zone is explicit on both
  # sides: Solid Queue reads a bare crontab in the app's zone, Sentry in UTC.
  SCHEDULE = "15 3 * * *".freeze
  TIME_ZONE = "America/Los_Angeles".freeze
  sentry_monitor_check_ins slug: "nightly-backup",
    monitor_config: Sentry::Cron::MonitorConfig.from_crontab(SCHEDULE, timezone: TIME_ZONE)

  queue_as :default

  def perform(bucket: nil, passphrase: ENV["BACKUP_PASSPHRASE"], storage_root: Rails.root.join("storage").to_s)
    bucket ||= BackupBucket.new if BackupBucket.configured?
    return if bucket.nil?

    Dir.mktmpdir do |dir|
      dump = DatabaseDump.new(passphrase: passphrase).write(File.join(dir, "backup.dump.enc"))
      bucket.upload("db/conduit_app-#{Time.current.utc.strftime('%Y-%m-%dT%H%MZ')}.dump.enc", dump)
    end
    StorageBackup.new(root: storage_root, bucket: bucket).sync
  end
end
