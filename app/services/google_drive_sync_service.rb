# frozen_string_literal: true

# Service responsible for syncing folder structure and files from Google Drive
# This is a read-only sync - we never modify Google Drive
class GoogleDriveSyncService
  def initialize(community, root_folder_id = nil)
    @community = community
    @root_folder_id = root_folder_id || community.settings&.dig("google_drive_folder_id") || ENV["GOOGLE_DRIVE_FOLDER_ID"]
    @api = GoogleDriveApiService.from_service_account
  end

  def sync!
    return { success: false, message: "No Google Drive folder configured" } unless @root_folder_id.present?

    ActsAsTenant.with_tenant(@community) do
      # Fetch folder structure from Drive
      folder_result = @api.list_folder_tree(@root_folder_id)
      return { success: false, message: "Failed to fetch folders: #{folder_result[:error]}" } unless folder_result[:status] == :success

      drive_folders = folder_result[:folders]

      # Sync folders first
      folders_created, folders_updated = sync_folders(drive_folders)

      # Build list of all folder IDs to fetch files from (root + all subfolders)
      all_folder_ids = [ @root_folder_id ] + drive_folders.map { |f| f[:id] }

      # Fetch and sync files
      files_result = @api.list_files_in_folders(all_folder_ids)
      return { success: false, message: "Failed to fetch files: #{files_result[:error]}" } unless files_result[:status] == :success

      files_created, files_updated = sync_files(files_result[:files], drive_folders)

      # Clean up folders that no longer exist in Drive
      folders_removed = cleanup_removed_folders(drive_folders)

      {
        success: true,
        message: build_sync_message(folders_created, folders_updated, folders_removed, files_created, files_updated),
        folders_created: folders_created,
        folders_updated: folders_updated,
        folders_removed: folders_removed,
        files_created: files_created,
        files_updated: files_updated
      }
    end
  end

  private

  def sync_folders(drive_folders)
    folders_created = 0
    folders_updated = 0

    # Build a map of Drive folder ID to parent Drive folder ID
    parent_map = drive_folders.each_with_object({}) do |folder, map|
      map[folder[:id]] = folder[:parents]&.first
    end

    # Process folders in order (parents before children) using topological sort
    sorted_folders = topological_sort(drive_folders, parent_map)

    sorted_folders.each do |drive_folder|
      existing = DocumentFolder.find_by(google_drive_id: drive_folder[:id])

      # Determine parent folder
      drive_parent_id = parent_map[drive_folder[:id]]
      local_parent = if drive_parent_id && drive_parent_id != @root_folder_id
        DocumentFolder.find_by(google_drive_id: drive_parent_id)
      end

      if existing
        # Update if name changed
        if existing.name != drive_folder[:name] || existing.parent_id != local_parent&.id
          existing.update!(name: drive_folder[:name], parent: local_parent)
          folders_updated += 1
        end
      else
        # Create new folder
        DocumentFolder.create!(
          name: drive_folder[:name],
          google_drive_id: drive_folder[:id],
          parent: local_parent,
          community: @community
        )
        folders_created += 1
      end
    end

    [ folders_created, folders_updated ]
  end

  def sync_files(drive_files, drive_folders)
    files_created = 0
    files_updated = 0

    # Build folder mapping
    folder_id_map = drive_folders.each_with_object({}) do |folder, map|
      local_folder = DocumentFolder.find_by(google_drive_id: folder[:id])
      map[folder[:id]] = local_folder&.id
    end

    drive_files.each do |drive_file|
      # Skip non-Google Docs/Sheets/Slides
      next unless google_doc_type?(drive_file[:mime_type])

      # Find or create document
      existing = Document.find_by(google_drive_url: drive_file[:web_link])

      # Determine local folder
      drive_parent_id = drive_file[:parents]&.first
      local_folder_id = if drive_parent_id == @root_folder_id
        nil # Root level
      else
        folder_id_map[drive_parent_id]
      end

      if existing
        # Update folder assignment if changed
        if existing.document_folder_id != local_folder_id
          existing.update!(document_folder_id: local_folder_id)
          files_updated += 1
        end
      else
        # Create new document
        Document.create!(
          title: drive_file[:name],
          google_drive_url: drive_file[:web_link],
          document_type: document_type_from_mime(drive_file[:mime_type]),
          storage_type: :google_drive,
          document_folder_id: local_folder_id,
          community: @community
        )
        files_created += 1
      end
    end

    [ files_created, files_updated ]
  end

  def cleanup_removed_folders(drive_folders)
    folders_removed = 0

    # Get all synced folders that are no longer in Drive
    drive_folder_ids = drive_folders.map { |f| f[:id] }
    orphaned_folders = DocumentFolder.synced_from_drive
                                     .where.not(google_drive_id: drive_folder_ids)

    orphaned_folders.each do |folder|
      # Move documents to root before deleting folder
      folder.documents.update_all(document_folder_id: nil)
      folder.destroy
      folders_removed += 1
    end

    folders_removed
  end

  def topological_sort(folders, parent_map)
    # Sort folders so parents come before children
    sorted = []
    visited = Set.new
    temp_visited = Set.new

    folders_by_id = folders.index_by { |f| f[:id] }

    visit = lambda do |folder|
      return if visited.include?(folder[:id])
      return if temp_visited.include?(folder[:id]) # Cycle detection

      temp_visited.add(folder[:id])

      # Visit parent first if it's in our folder set
      parent_id = parent_map[folder[:id]]
      if parent_id && folders_by_id[parent_id]
        visit.call(folders_by_id[parent_id])
      end

      temp_visited.delete(folder[:id])
      visited.add(folder[:id])
      sorted << folder
    end

    folders.each { |f| visit.call(f) }
    sorted
  end

  def google_doc_type?(mime_type)
    %w[
      application/vnd.google-apps.document
      application/vnd.google-apps.spreadsheet
      application/vnd.google-apps.presentation
    ].include?(mime_type)
  end

  def document_type_from_mime(mime_type)
    Document.document_type_from_mime(mime_type)
  end

  def build_sync_message(folders_created, folders_updated, folders_removed, files_created, files_updated)
    parts = []
    parts << "#{folders_created} folder(s) created" if folders_created > 0
    parts << "#{folders_updated} folder(s) updated" if folders_updated > 0
    parts << "#{folders_removed} folder(s) removed" if folders_removed > 0
    parts << "#{files_created} document(s) imported" if files_created > 0
    parts << "#{files_updated} document(s) updated" if files_updated > 0

    if parts.empty?
      "Already in sync with Google Drive"
    else
      "Sync complete: #{parts.join(', ')}"
    end
  end
end
