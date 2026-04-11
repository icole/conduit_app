# frozen_string_literal: true

namespace :drive do
  desc "Copy all files from community Drive folder to a Shared Drive, preserving folder structure"
  task :copy_to_shared_drive, [ :shared_drive_id ] => :environment do |_t, args|
    shared_drive_id = args[:shared_drive_id]
    abort "Usage: rails drive:copy_to_shared_drive[SHARED_DRIVE_ID]" unless shared_drive_id.present?

    community = Community.first
    source_folder_id = community.google_drive_folder_id
    abort "No google_drive_folder_id configured for community" unless source_folder_id.present?

    api = GoogleDriveApiService.from_service_account_with_permissions_scope

    puts "Copying from folder #{source_folder_id} to Shared Drive #{shared_drive_id}"
    puts "=" * 60

    # Map of old folder ID => new folder ID in Shared Drive
    folder_map = { source_folder_id => shared_drive_id }

    copied = 0
    folders_created = 0
    errors = 0
    error_list = []

    # Process folders breadth-first to build folder structure first
    folders_to_process = [ source_folder_id ]
    processed = Set.new

    puts "\n--- Phase 1: Recreating folder structure ---\n\n"

    while folders_to_process.any?
      current = folders_to_process.shift
      next if processed.include?(current)
      processed.add(current)

      begin
        query = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
        response = api.drive_service.list_files(
          q: query,
          fields: "files(id, name)",
          supports_all_drives: true,
          include_items_from_all_drives: true
        )

        (response.files || []).each do |folder|
          begin
            # Create corresponding folder in Shared Drive
            new_folder = Google::Apis::DriveV3::File.new(
              name: folder.name,
              mime_type: "application/vnd.google-apps.folder",
              parents: [ folder_map[current] ]
            )

            created = api.drive_service.create_file(
              new_folder,
              fields: "id, name",
              supports_all_drives: true
            )

            folder_map[folder.id] = created.id
            folders_created += 1
            puts "  FOLDER: #{folder.name} => #{created.id}"

            folders_to_process << folder.id
          rescue StandardError => e
            puts "  ERROR creating folder #{folder.name}: #{e.message}"
            errors += 1
            error_list << "FOLDER: #{folder.name} - #{e.message}"
          end
        end
      rescue StandardError => e
        puts "  ERROR listing folder #{current}: #{e.message}"
        errors += 1
        error_list << "LIST: #{current} - #{e.message}"
      end

      sleep 0.1
    end

    puts "\nCreated #{folders_created} folders"
    puts "\n--- Phase 2: Copying files ---\n\n"

    # Now copy files into the correct folders
    processed.each do |source_folder|
      dest_folder = folder_map[source_folder]

      begin
        query = "mimeType != 'application/vnd.google-apps.folder' and trashed = false and '#{source_folder}' in parents"
        response = api.drive_service.list_files(
          q: query,
          fields: "files(id, name, mimeType, owners)",
          supports_all_drives: true,
          include_items_from_all_drives: true
        )

        (response.files || []).each do |file|
          begin
            # Copy the file to the Shared Drive
            copy_metadata = Google::Apis::DriveV3::File.new(
              name: file.name,
              parents: [ dest_folder ]
            )

            api.drive_service.copy_file(
              file.id,
              copy_metadata,
              fields: "id, name",
              supports_all_drives: true
            )

            copied += 1
            owner = file.owners&.first&.email_address || "unknown"
            puts "  [#{copied}] #{file.name} (#{owner})"
          rescue StandardError => e
            puts "  ERROR copying #{file.name}: #{e.message}"
            errors += 1
            error_list << "FILE: #{file.name} - #{e.message}"
          end

          sleep 0.2
        end
      rescue StandardError => e
        puts "  ERROR listing files in #{source_folder}: #{e.message}"
        errors += 1
        error_list << "LIST FILES: #{source_folder} - #{e.message}"
      end
    end

    puts ""
    puts "=" * 60
    puts "Done!"
    puts "  Folders created: #{folders_created}"
    puts "  Files copied: #{copied}"
    puts "  Errors: #{errors}"

    if error_list.any?
      puts "\nErrors:"
      error_list.each { |e| puts "  - #{e}" }
    end

    puts "\nNew Shared Drive ID: #{shared_drive_id}"
    puts "Update GOOGLE_DRIVE_FOLDER_ID to this value when ready."
  end
end
