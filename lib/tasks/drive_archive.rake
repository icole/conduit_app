# frozen_string_literal: true

namespace :drive do
  desc "Prefix all files and folders in the old Drive folder with [ARCHIVED]"
  task :archive_old_files, [ :folder_id ] => :environment do |_t, args|
    folder_id = args[:folder_id] || Community.first.google_drive_folder_id
    abort "No folder_id provided or configured" unless folder_id.present?

    api = GoogleDriveApiService.from_service_account_with_permissions_scope

    puts "Archiving files in #{folder_id}"
    puts "=" * 60

    folders_to_process = [ folder_id ]
    processed = Set.new
    renamed = 0
    skipped = 0
    errors = 0

    while folders_to_process.any?
      current = folders_to_process.shift
      next if processed.include?(current)
      processed.add(current)

      # Get all items (folders and files) in current folder
      query = "trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(q: query, fields: "files(id, name, mimeType)")

      (response.files || []).each do |file|
        # Queue subfolders for processing
        if file.mime_type == "application/vnd.google-apps.folder"
          folders_to_process << file.id
        end

        if file.name.start_with?("[ARCHIVED]")
          skipped += 1
          next
        end

        new_name = "[ARCHIVED] #{file.name}"
        begin
          api.drive_service.update_file(
            file.id,
            Google::Apis::DriveV3::File.new(name: new_name)
          )
          renamed += 1
          puts "  #{file.name} -> #{new_name}"
        rescue StandardError => e
          puts "  ERROR renaming #{file.name}: #{e.message}"
          errors += 1
        end

        sleep 0.1
      end

      sleep 0.1
    end

    # Also rename the root folder itself
    begin
      root = api.drive_service.get_file(folder_id, fields: "name")
      unless root.name.start_with?("[ARCHIVED]")
        new_name = "[ARCHIVED] #{root.name}"
        api.drive_service.update_file(
          folder_id,
          Google::Apis::DriveV3::File.new(name: new_name)
        )
        puts "\n  Root folder: #{root.name} -> #{new_name}"
        renamed += 1
      end
    rescue StandardError => e
      puts "  ERROR renaming root folder: #{e.message}"
      errors += 1
    end

    puts ""
    puts "=" * 60
    puts "Done!"
    puts "  Renamed: #{renamed}"
    puts "  Already archived: #{skipped}"
    puts "  Errors: #{errors}"
  end
end
