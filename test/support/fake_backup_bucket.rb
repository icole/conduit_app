# Stands in for BackupBucket in tests: object name => base64 MD5, as Cloud
# Storage reports it, plus a record of what was uploaded and deleted.
class FakeBackupBucket
  attr_reader :objects, :uploads, :deletes

  def initialize(objects = {})
    @objects = objects
    @uploads = []
    @deletes = []
  end

  def list(prefix) = objects.select { |name, _| name.start_with?(prefix) }

  def upload(name, path)
    uploads << name
    objects[name] = Digest::MD5.file(path).base64digest
  end

  def delete(name)
    deletes << name
    objects.delete(name)
  end
end
