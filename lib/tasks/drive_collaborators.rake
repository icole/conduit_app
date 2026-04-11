# frozen_string_literal: true

namespace :drive do
  desc "List all unique collaborators across source Drive files"
  task list_collaborators: :environment do
    community = Community.first
    source_folder_id = community.google_drive_folder_id
    abort "No google_drive_folder_id configured" unless source_folder_id.present?

    api = GoogleDriveApiService.from_service_account_with_permissions_scope

    puts "Scanning collaborators in #{source_folder_id}"
    puts "=" * 60

    collaborators = {}
    folders_to_process = [ source_folder_id ]
    processed = Set.new
    file_count = 0

    while folders_to_process.any?
      current = folders_to_process.shift
      next if processed.include?(current)
      processed.add(current)

      # Get subfolders
      query = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(q: query, fields: "files(id, name)")
      (response.files || []).each { |f| folders_to_process << f.id }

      # Get files
      query = "mimeType != 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(q: query, fields: "files(id, name)")
      (response.files || []).each do |file|
        file_count += 1
        print "\rScanning file #{file_count}..."

        begin
          perms = api.drive_service.list_permissions(
            file.id,
            fields: "permissions(emailAddress, role, type, displayName)"
          )
          (perms.permissions || []).each do |perm|
            next unless perm.type == "user" && perm.email_address.present?
            email = perm.email_address.downcase
            collaborators[email] ||= { name: perm.display_name, roles: Set.new, file_count: 0 }
            collaborators[email][:roles].add(perm.role)
            collaborators[email][:file_count] += 1
          end
        rescue StandardError => e
          # Some files may not allow permission listing
          next
        end

        sleep 0.05
      end

      sleep 0.1
    end

    puts "\n\n"
    puts "Found #{collaborators.length} unique collaborators across #{file_count} files:"
    puts "-" * 60

    collaborators.sort_by { |email, _| email }.each do |email, info|
      roles = info[:roles].to_a.join(", ")
      puts "  #{email} (#{info[:name] || 'unknown'}) — #{roles} on #{info[:file_count]} files"
    end
  end

  desc "Add collaborators from source Drive files as Shared Drive members"
  task :add_collaborators_to_shared_drive, [ :shared_drive_id ] => :environment do |_t, args|
    shared_drive_id = args[:shared_drive_id]
    abort "Usage: rails drive:add_collaborators_to_shared_drive[SHARED_DRIVE_ID]" unless shared_drive_id.present?

    community = Community.first
    source_folder_id = community.google_drive_folder_id
    abort "No google_drive_folder_id configured" unless source_folder_id.present?

    api = GoogleDriveApiService.from_service_account_with_permissions_scope

    puts "Scanning collaborators in #{source_folder_id}"
    puts "=" * 60

    collaborators = {}
    folders_to_process = [ source_folder_id ]
    processed = Set.new
    file_count = 0

    while folders_to_process.any?
      current = folders_to_process.shift
      next if processed.include?(current)
      processed.add(current)

      query = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(q: query, fields: "files(id, name)")
      (response.files || []).each { |f| folders_to_process << f.id }

      query = "mimeType != 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(q: query, fields: "files(id, name)")
      (response.files || []).each do |file|
        file_count += 1
        print "\rScanning file #{file_count}..."

        begin
          perms = api.drive_service.list_permissions(
            file.id,
            fields: "permissions(emailAddress, role, type, displayName)"
          )
          (perms.permissions || []).each do |perm|
            next unless perm.type == "user" && perm.email_address.present?
            email = perm.email_address.downcase
            collaborators[email] ||= { name: perm.display_name, roles: Set.new }
            collaborators[email][:roles].add(perm.role)
          end
        rescue StandardError => e
          next
        end

        sleep 0.05
      end

      sleep 0.1
    end

    puts "\n\nFound #{collaborators.length} unique collaborators"
    puts "-" * 60

    # Map Drive file roles to Shared Drive roles
    # owner/writer -> fileOrganizer (can manage files but not members)
    # commenter/reader -> reader
    added = 0
    skipped = 0
    errors = 0

    collaborators.sort_by { |email, _| email }.each do |email, info|
      # Determine best role: if they had writer/owner access, give fileOrganizer; otherwise reader
      shared_drive_role = if info[:roles].intersect?(Set["owner", "writer"])
        "fileOrganizer"
      elsif info[:roles].include?("commenter")
        "commenter"
      else
        "reader"
      end

      puts "  Adding #{email} (#{info[:name]}) as #{shared_drive_role}..."

      begin
        permission = Google::Apis::DriveV3::Permission.new(
          type: "user",
          role: shared_drive_role,
          email_address: email
        )
        api.drive_service.create_permission(
          shared_drive_id,
          permission,
          supports_all_drives: true,
          send_notification_email: false
        )
        added += 1
      rescue Google::Apis::ClientError => e
        if e.message.include?("alreadyExist") || e.message.include?("already")
          puts "    Already a member, skipping"
          skipped += 1
        else
          puts "    ERROR: #{e.message}"
          errors += 1
        end
      rescue StandardError => e
        puts "    ERROR: #{e.message}"
        errors += 1
      end

      sleep 0.1
    end

    puts "\n"
    puts "=" * 60
    puts "Done!"
    puts "  Added: #{added}"
    puts "  Already members: #{skipped}"
    puts "  Errors: #{errors}"
  end
end
