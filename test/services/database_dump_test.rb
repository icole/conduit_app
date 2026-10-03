require "test_helper"
require "open3"

class DatabaseDumpTest < ActiveSupport::TestCase
  PASSPHRASE = "test-passphrase-not-a-secret"

  test "writes an encrypted dump that the passphrase and standard tools alone can restore" do
    Dir.mktmpdir do |dir|
      path = DatabaseDump.new(passphrase: PASSPHRASE).write(File.join(dir, "backup.dump.enc"))

      assert_not File.binread(path, 5) == "PGDMP", "the file on disk is encrypted, not a readable dump"

      # The documented restore: openssl to decrypt, pg_restore to read it
      plain = File.join(dir, "backup.dump")
      _, err, status = Open3.capture3({ "BACKUP_PASSPHRASE" => PASSPHRASE },
        *DatabaseDump::DECRYPT, "-in", path, "-out", plain)
      assert status.success?, err
      listing, err, status = Open3.capture3("pg_restore", "--list", plain)
      assert status.success?, err
      assert_match(/TABLE public users/, listing)
    end
  end

  test "the wrong passphrase can't decrypt it" do
    Dir.mktmpdir do |dir|
      path = DatabaseDump.new(passphrase: PASSPHRASE).write(File.join(dir, "backup.dump.enc"))
      _, _, status = Open3.capture3({ "BACKUP_PASSPHRASE" => "wrong" },
        *DatabaseDump::DECRYPT, "-in", path, "-out", File.join(dir, "out"))
      assert_not status.success?
    end
  end

  test "a failed dump raises instead of leaving a half-written backup to upload" do
    Dir.mktmpdir do |dir|
      dump = DatabaseDump.new(passphrase: PASSPHRASE, config: { database: "no_such_database_here" })
      assert_raises(DatabaseDump::Failed) { dump.write(File.join(dir, "backup.dump.enc")) }
    end
  end
end
