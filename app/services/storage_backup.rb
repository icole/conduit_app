# Mirrors the uploaded files (Active Storage's local disk) into the backups
# bucket, copying only what's new or changed and removing what's gone. The
# bucket keeps removed and overwritten versions for 30 days (CON-31).
class StorageBackup
  PREFIX = "files/".freeze

  def initialize(root:, bucket:)
    @root = root
    @bucket = bucket
  end

  def sync
    remote = @bucket.list(PREFIX)
    local = Dir.glob("**/*", base: @root).select { |relative| File.file?(File.join(@root, relative)) }

    uploaded = 0
    local.each do |relative|
      path = File.join(@root, relative)
      next if remote[PREFIX + relative] == Digest::MD5.file(path).base64digest

      @bucket.upload(PREFIX + relative, path)
      uploaded += 1
    end

    gone = remote.keys - local.map { |relative| PREFIX + relative }
    gone.each { |name| @bucket.delete(name) }

    { uploaded: uploaded, deleted: gone.size, unchanged: local.size - uploaded }
  end
end
