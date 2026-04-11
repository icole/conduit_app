# frozen_string_literal: true

namespace :drive do
  desc "Copy comments from original Drive files to their copies in the Shared Drive"
  task :copy_comments, [ :shared_drive_id ] => :environment do |_t, args|
    shared_drive_id = args[:shared_drive_id]
    abort "Usage: rails drive:copy_comments[SHARED_DRIVE_ID]" unless shared_drive_id.present?

    community = Community.first
    source_folder_id = community.google_drive_folder_id
    abort "No google_drive_folder_id configured" unless source_folder_id.present?

    api = GoogleDriveApiService.from_service_account_with_permissions_scope

    puts "Migrating comments from #{source_folder_id} to Shared Drive #{shared_drive_id}"
    puts "=" * 60

    # Phase 1: Build a map of source files by name+parent path
    puts "\n--- Phase 1: Indexing source files ---\n\n"

    source_files = {}
    source_folder_names = { source_folder_id => "" }
    folders_to_process = [ source_folder_id ]
    processed = Set.new

    while folders_to_process.any?
      current = folders_to_process.shift
      next if processed.include?(current)
      processed.add(current)

      parent_path = source_folder_names[current]

      # Index subfolders
      query = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(q: query, fields: "files(id, name)")
      (response.files || []).each do |f|
        path = parent_path.empty? ? f.name : "#{parent_path}/#{f.name}"
        source_folder_names[f.id] = path
        folders_to_process << f.id
      end

      # Index files
      query = "mimeType != 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(q: query, fields: "files(id, name)")
      (response.files || []).each do |f|
        key = parent_path.empty? ? f.name : "#{parent_path}/#{f.name}"
        source_files[key] = f.id
      end

      sleep 0.1
    end

    puts "Indexed #{source_files.length} source files"

    # Phase 2: Build a map of destination files by name+parent path
    puts "\n--- Phase 2: Indexing destination files ---\n\n"

    dest_files = {}
    dest_folder_names = { shared_drive_id => "" }
    folders_to_process = [ shared_drive_id ]
    processed = Set.new

    while folders_to_process.any?
      current = folders_to_process.shift
      next if processed.include?(current)
      processed.add(current)

      parent_path = dest_folder_names[current]

      query = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(
        q: query, fields: "files(id, name)",
        supports_all_drives: true,
        include_items_from_all_drives: true,
        corpora: "drive", drive_id: shared_drive_id
      )
      (response.files || []).each do |f|
        path = parent_path.empty? ? f.name : "#{parent_path}/#{f.name}"
        dest_folder_names[f.id] = path
        folders_to_process << f.id
      end

      query = "mimeType != 'application/vnd.google-apps.folder' and trashed = false and '#{current}' in parents"
      response = api.drive_service.list_files(
        q: query, fields: "files(id, name)",
        supports_all_drives: true,
        include_items_from_all_drives: true,
        corpora: "drive", drive_id: shared_drive_id
      )
      (response.files || []).each do |f|
        key = parent_path.empty? ? f.name : "#{parent_path}/#{f.name}"
        dest_files[key] = f.id
      end

      sleep 0.1
    end

    puts "Indexed #{dest_files.length} destination files"

    # Phase 3: For each source file, check for comments and copy them
    puts "\n--- Phase 3: Copying comments ---\n\n"

    files_with_comments = 0
    comments_copied = 0
    replies_copied = 0
    errors = 0
    skipped = 0

    source_files.each do |path, source_id|
      dest_id = dest_files[path]

      unless dest_id
        puts "  SKIP (no match): #{path}"
        skipped += 1
        next
      end

      begin
        # List comments on source file
        comments_response = api.drive_service.list_comments(
          source_id,
          fields: "comments(id, content, author(displayName, emailAddress), createdTime, resolved, replies(content, author(displayName, emailAddress), createdTime))",
          include_deleted: false
        )

        comments = comments_response.comments || []
        next if comments.empty?

        files_with_comments += 1
        puts "  #{path}: #{comments.length} comments"

        comments.each do |comment|
          author_name = comment.author&.display_name || comment.author&.email_address || "Unknown"
          author_email = comment.author&.email_address || ""
          created = comment.created_time&.strftime("%b %-d, %Y at %-I:%M %p") || ""

          # Build comment text with original author attribution
          new_content = "**#{author_name}** (#{author_email}) — #{created}:\n\n#{comment.content}"
          if comment.resolved
            new_content += "\n\n[This comment was resolved]"
          end

          begin
            new_comment = Google::Apis::DriveV3::Comment.new(content: new_content)
            created_comment = api.drive_service.create_comment(
              dest_id,
              new_comment,
              fields: "id"
            )
            comments_copied += 1

            # Copy replies
            (comment.replies || []).each do |reply|
              reply_author = reply.author&.display_name || reply.author&.email_address || "Unknown"
              reply_email = reply.author&.email_address || ""
              reply_created = reply.created_time&.strftime("%b %-d, %Y at %-I:%M %p") || ""

              reply_content = "**#{reply_author}** (#{reply_email}) — #{reply_created}:\n\n#{reply.content}"

              new_reply = Google::Apis::DriveV3::Reply.new(content: reply_content)
              api.drive_service.create_reply(
                dest_id,
                created_comment.id,
                new_reply,
                fields: "id"
              )
              replies_copied += 1
            end
          rescue StandardError => e
            puts "    ERROR on comment: #{e.message}"
            errors += 1
          end

          sleep 0.2
        end
      rescue Google::Apis::ClientError => e
        # Some file types don't support comments (images, PDFs uploaded as binary)
        next if e.message.include?("commentsDisabled") || e.message.include?("notFound")
        puts "  ERROR reading comments for #{path}: #{e.message}"
        errors += 1
      rescue StandardError => e
        puts "  ERROR on #{path}: #{e.message}"
        errors += 1
      end

      sleep 0.1
    end

    puts ""
    puts "=" * 60
    puts "Done!"
    puts "  Files with comments: #{files_with_comments}"
    puts "  Comments copied: #{comments_copied}"
    puts "  Replies copied: #{replies_copied}"
    puts "  Skipped (no match): #{skipped}"
    puts "  Errors: #{errors}"
  end
end
