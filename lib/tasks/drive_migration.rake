# frozen_string_literal: true

namespace :drive do
  desc "Transfer ownership of all files in community Drive folder to a new owner"
  task :transfer_ownership, [ :new_owner_email ] => :environment do |_t, args|
    new_owner = args[:new_owner_email]
    abort "Usage: rails drive:transfer_ownership[email@example.com]" unless new_owner.present?

    community = Community.first
    folder_id = community.google_drive_folder_id
    abort "No google_drive_folder_id configured for community" unless folder_id.present?

    puts "Transferring ownership of all files in folder #{folder_id} to #{new_owner}"
    puts "=" * 60

    api = GoogleDriveApiService.from_service_account_with_permissions_scope

    # Collect all file and folder IDs recursively
    all_items = []
    folders_to_process = [ folder_id ]
    processed = Set.new

    while folders_to_process.any?
      current = folders_to_process.shift
      next if processed.include?(current)
      processed.add(current)

      # Get subfolders
      query = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(q: query, fields: "files(id, name)")
      (response.files || []).each do |f|
        all_items << { id: f.id, name: f.name, type: "folder" }
        folders_to_process << f.id
      end

      # Get files
      query = "mimeType != 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(q: query, fields: "files(id, name, owners)")
      (response.files || []).each do |f|
        owner_email = f.owners&.first&.email_address
        all_items << { id: f.id, name: f.name, type: "file", owner: owner_email }
      end
    end

    # Also include the root folder itself
    all_items.unshift({ id: folder_id, name: "(root folder)", type: "folder" })

    puts "Found #{all_items.length} items to process"
    puts ""

    transferred = 0
    skipped = 0
    errors = 0

    all_items.each_with_index do |item, i|
      if item[:owner] == new_owner
        puts "[#{i + 1}/#{all_items.length}] SKIP (already owned): #{item[:name]}"
        skipped += 1
        next
      end

      begin
        permission = Google::Apis::DriveV3::Permission.new(
          type: "user",
          email_address: new_owner,
          role: "owner"
        )

        api.drive_service.create_permission(
          item[:id],
          permission,
          transfer_ownership: true,
          send_notification_email: false,
          fields: "id"
        )

        puts "[#{i + 1}/#{all_items.length}] OK: #{item[:name]} (#{item[:type]})"
        transferred += 1
      rescue Google::Apis::ClientError => e
        puts "[#{i + 1}/#{all_items.length}] ERROR: #{item[:name]} - #{e.message}"
        errors += 1
      end

      # Rate limit: Google Drive API has 10 queries/sec/user limit
      sleep 0.2
    end

    puts ""
    puts "=" * 60
    puts "Done! Transferred: #{transferred}, Skipped: #{skipped}, Errors: #{errors}"
  end

  desc "List all files and their owners in community Drive folder (dry run)"
  task list_owners: :environment do
    community = Community.first
    folder_id = community.google_drive_folder_id
    abort "No google_drive_folder_id configured" unless folder_id.present?

    puts "Listing owners of all files in folder #{folder_id}"
    puts "=" * 60

    api = GoogleDriveApiService.from_service_account

    folders_to_process = [ folder_id ]
    processed = Set.new
    owners = Hash.new(0)

    while folders_to_process.any?
      current = folders_to_process.shift
      next if processed.include?(current)
      processed.add(current)

      query = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(q: query, fields: "files(id, name)")
      (response.files || []).each do |f|
        folders_to_process << f.id
      end

      query = "mimeType != 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(q: query, fields: "files(id, name, owners)")
      (response.files || []).each do |f|
        owner = f.owners&.first&.email_address || "unknown"
        owners[owner] += 1
        puts "  #{owner} => #{f.name}"
      end
    end

    puts ""
    puts "=" * 60
    puts "Summary by owner:"
    owners.sort_by { |_, count| -count }.each do |email, count|
      puts "  #{email}: #{count} files"
    end
  end
end
