require "google/apis/storage_v1"

# The backups bucket in Google Cloud Storage (CON-31), written by a service
# account whose only permission is on this bucket.
class BackupBucket
  def self.configured?
    ENV["BACKUP_BUCKET"].present? && ENV["BACKUP_GCS_CREDENTIALS"].present?
  end

  def initialize(name: ENV.fetch("BACKUP_BUCKET"), credentials: ENV.fetch("BACKUP_GCS_CREDENTIALS"))
    @name = name
    @service = Google::Apis::StorageV1::StorageService.new
    @service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(Base64.decode64(credentials)),
      scope: Google::Apis::StorageV1::AUTH_DEVSTORAGE_READ_WRITE
    )
  end

  # Object name => base64 MD5, for everything under +prefix+
  def list(prefix)
    objects = {}
    page_token = nil
    loop do
      page = @service.list_objects(@name, prefix: prefix, page_token: page_token, fields: "items(name,md5Hash),nextPageToken")
      Array(page.items).each { |object| objects[object.name] = object.md5_hash }
      break unless (page_token = page.next_page_token)
    end
    objects
  end

  def upload(name, path)
    @service.insert_object(@name, Google::Apis::StorageV1::Object.new(name: name),
      upload_source: path, content_type: "application/octet-stream")
  end

  def delete(name)
    @service.delete_object(@name, name)
  end
end
