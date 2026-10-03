require "test_helper"
require_relative "../support/fake_backup_bucket"

class StorageBackupTest < ActiveSupport::TestCase
  test "uploads new and changed files, skips unchanged ones, and removes what's gone" do
    Dir.mktmpdir do |root|
      File.write(File.join(root, "same"), "unchanged")
      FileUtils.mkdir_p(File.join(root, "ab", "cd"))
      File.write(File.join(root, "ab", "cd", "photo"), "new photo")
      File.write(File.join(root, "changed"), "edited")

      bucket = FakeBackupBucket.new(
        "files/same" => Digest::MD5.base64digest("unchanged"),
        "files/changed" => Digest::MD5.base64digest("original"),
        "files/deleted" => "whatever"
      )
      result = StorageBackup.new(root: root, bucket: bucket).sync

      assert_equal %w[files/ab/cd/photo files/changed], bucket.uploads.sort
      assert_equal %w[files/deleted], bucket.deletes
      assert_equal({ uploaded: 2, deleted: 1, unchanged: 1 }, result)
    end
  end
end
