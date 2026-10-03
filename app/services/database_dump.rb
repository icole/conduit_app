require "open3"

# A pg_dump of the main database, encrypted with the backup passphrase
# (CON-31). Restoring needs only standard tools and the passphrase; see
# "Restoring a backup" in DEPLOYMENT.md.
class DatabaseDump
  class Failed < StandardError; end

  CIPHER = %w[-aes-256-cbc -pbkdf2 -iter 600000 -md sha256].freeze
  ENCRYPT = [ "openssl", "enc", "-e", *CIPHER, "-salt", "-pass", "env:BACKUP_PASSPHRASE" ].freeze
  DECRYPT = [ "openssl", "enc", "-d", *CIPHER, "-pass", "env:BACKUP_PASSPHRASE" ].freeze

  def initialize(passphrase:, config: {})
    raise ArgumentError, "a backup passphrase is required" if passphrase.blank?

    @passphrase = passphrase
    @config = ActiveRecord::Base.connection_db_config.configuration_hash.merge(config)
  end

  # Writes the encrypted dump to +path+ and returns it. Raises Failed (and
  # leaves nothing behind) if either step fails, so a broken dump is never
  # uploaded as if it were a backup.
  def write(path)
    Tempfile.create("dump-errors") do |errors|
      statuses = Open3.pipeline(
        [ { "PGPASSWORD" => @config[:password].to_s }, *dump_command, { err: errors.path } ],
        [ { "BACKUP_PASSPHRASE" => @passphrase }, *ENCRYPT, "-out", path, { err: errors.path } ]
      )
      next path if statuses.all?(&:success?)

      FileUtils.rm_f(path)
      raise Failed, "database dump failed: #{File.read(errors.path).strip.first(500)}"
    end
  end

  private

  # Custom format: compressed, and pg_restore can restore all or part of it
  def dump_command
    command = [ "pg_dump", "--format=custom", "--no-owner", "--no-privileges" ]
    command += [ "--host", @config[:host].to_s ] if @config[:host].present?
    command += [ "--port", @config[:port].to_s ] if @config[:port].present?
    command += [ "--username", @config[:username].to_s ] if @config[:username].present?
    command + [ @config[:database].to_s ]
  end
end
