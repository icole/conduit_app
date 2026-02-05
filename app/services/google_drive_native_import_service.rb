# frozen_string_literal: true

# Service responsible for importing Google Drive documents as native documents with HTML content.
# This is a one-way import: reads from Drive, creates/converts native documents, never modifies Drive.
class GoogleDriveNativeImportService
  def initialize(community)
    @community = community
    @root_folder_id = community.google_drive_folder_id || ENV["GOOGLE_DRIVE_FOLDER_ID"]
    @api = GoogleDriveApiService.from_service_account
  end

  def import!
    return { success: false, message: "No Google Drive folder configured" } unless @root_folder_id.present?

    ActsAsTenant.with_tenant(@community) do
      # Fetch folder structure from Drive
      folder_result = @api.list_folder_tree(@root_folder_id)
      return { success: false, message: "Failed to fetch folders: #{folder_result[:error]}" } unless folder_result[:status] == :success

      drive_folders = folder_result[:folders]

      # Sync folders (create/update DocumentFolder records)
      folders_created, folders_updated = sync_folders(drive_folders)

      # Build list of all folder IDs to fetch files from
      all_folder_ids = [ @root_folder_id ] + drive_folders.map { |f| f[:id] }

      # Fetch files
      files_result = @api.list_files_in_folders(all_folder_ids)
      return { success: false, message: "Failed to fetch files: #{files_result[:error]}" } unless files_result[:status] == :success

      # Import files as native or uploaded documents
      docs_converted, docs_created, docs_uploaded, docs_skipped, errors = import_files(files_result[:files], drive_folders)

      {
        success: true,
        message: build_message(folders_created, folders_updated, docs_converted, docs_created, docs_uploaded, docs_skipped, errors),
        folders_created: folders_created,
        folders_updated: folders_updated,
        docs_converted: docs_converted,
        docs_created: docs_created,
        docs_uploaded: docs_uploaded,
        docs_skipped: docs_skipped,
        errors: errors
      }
    end
  end

  private

  def sync_folders(drive_folders)
    folders_created = 0
    folders_updated = 0

    parent_map = drive_folders.each_with_object({}) do |folder, map|
      map[folder[:id]] = folder[:parents]&.first
    end

    sorted_folders = topological_sort(drive_folders, parent_map)

    sorted_folders.each do |drive_folder|
      existing = DocumentFolder.find_by(google_drive_id: drive_folder[:id])

      drive_parent_id = parent_map[drive_folder[:id]]
      local_parent = if drive_parent_id && drive_parent_id != @root_folder_id
        DocumentFolder.find_by(google_drive_id: drive_parent_id)
      end

      if existing
        if existing.name != drive_folder[:name] || existing.parent_id != local_parent&.id
          existing.update!(name: drive_folder[:name], parent: local_parent)
          folders_updated += 1
        end
      else
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

  def import_files(drive_files, drive_folders)
    docs_converted = 0
    docs_created = 0
    docs_uploaded = 0
    docs_skipped = 0
    errors = []

    folder_id_map = drive_folders.each_with_object({}) do |folder, map|
      local_folder = DocumentFolder.find_by(google_drive_id: folder[:id])
      map[folder[:id]] = local_folder&.id
    end

    drive_files.each do |drive_file|
      web_link = drive_file[:web_link]
      file_id = extract_file_id(web_link)

      # Determine local folder
      drive_parent_id = drive_file[:parents]&.first
      local_folder_id = if drive_parent_id == @root_folder_id
        nil
      else
        folder_id_map[drive_parent_id]
      end

      existing = Document.find_by(google_drive_url: web_link)

      if existing&.native? || existing&.uploaded?
        # Already imported — skip
        Rails.logger.info("[DriveImport] Skipping already-imported: #{drive_file[:name]}")
        docs_skipped += 1
      elsif google_doc_type?(drive_file[:mime_type])
        # Google-native file — export as HTML
        if existing&.google_drive?
          result = export_and_update(existing, file_id, drive_file[:name], drive_file[:mime_type], local_folder_id)
          if result == :success
            docs_converted += 1
          else
            errors << result
          end
        else
          result = export_and_create(web_link, file_id, drive_file[:name], drive_file[:mime_type], local_folder_id)
          if result == :success
            docs_created += 1
          else
            errors << result
          end
        end
      else
        # Non-Google-native file — download and attach
        result = download_and_create(web_link, file_id, drive_file[:name], drive_file[:mime_type], local_folder_id)
        if result == :success
          docs_uploaded += 1
        else
          errors << result
        end
      end
    end

    [ docs_converted, docs_created, docs_uploaded, docs_skipped, errors ]
  end

  def export_and_update(document, file_id, name, mime_type, local_folder_id)
    Rails.logger.info("[DriveImport] Converting to native: #{name}")
    export_result = @api.export_as_html(file_id)

    unless export_result[:status] == :success
      msg = "Failed to export '#{name}': #{export_result[:error]}"
      Rails.logger.error("[DriveImport] #{msg}")
      return msg
    end

    document.update!(
      storage_type: :native,
      content: export_result[:content],
      document_type: document_type_from_mime(mime_type),
      document_folder_id: local_folder_id
    )
    :success
  end

  def export_and_create(web_link, file_id, name, mime_type, local_folder_id)
    Rails.logger.info("[DriveImport] Creating native doc: #{name}")
    export_result = @api.export_as_html(file_id)

    unless export_result[:status] == :success
      msg = "Failed to export '#{name}': #{export_result[:error]}"
      Rails.logger.error("[DriveImport] #{msg}")
      return msg
    end

    Document.create!(
      title: name,
      google_drive_url: web_link,
      storage_type: :native,
      content: export_result[:content],
      document_type: document_type_from_mime(mime_type),
      document_folder_id: local_folder_id,
      community: @community
    )
    :success
  end

  def download_and_create(web_link, file_id, name, mime_type, local_folder_id)
    Rails.logger.info("[DriveImport] Downloading uploaded file: #{name}")
    download_result = @api.download_file(file_id)

    unless download_result[:status] == :success
      msg = "Failed to download '#{name}': #{download_result[:error]}"
      Rails.logger.error("[DriveImport] #{msg}")
      return msg
    end

    doc = Document.new(
      title: name,
      google_drive_url: web_link,
      storage_type: :uploaded,
      document_type: document_type_from_mime(mime_type),
      document_folder_id: local_folder_id,
      community: @community
    )
    doc.file.attach(
      io: download_result[:content],
      filename: name,
      content_type: download_result[:mime_type]
    )
    doc.save!
    :success
  end

  def extract_file_id(url)
    return nil if url.blank?

    match = url.match(%r{/d/([a-zA-Z0-9_-]+)})
    match&.[](1)
  end

  def document_type_from_mime(mime_type)
    case mime_type
    when "application/vnd.google-apps.document"
      "Document"
    when "application/vnd.google-apps.spreadsheet"
      "Spreadsheet"
    when "application/vnd.google-apps.presentation"
      "Presentation"
    when "application/pdf"
      "PDF"
    when "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         "application/msword"
      "Word Document"
    when "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
         "application/vnd.ms-excel"
      "Excel Spreadsheet"
    when "application/vnd.openxmlformats-officedocument.presentationml.presentation",
         "application/vnd.ms-powerpoint"
      "PowerPoint"
    when /\Aimage\//
      "Image"
    else
      "File"
    end
  end

  def google_doc_type?(mime_type)
    %w[
      application/vnd.google-apps.document
      application/vnd.google-apps.spreadsheet
      application/vnd.google-apps.presentation
    ].include?(mime_type)
  end

  def topological_sort(folders, parent_map)
    sorted = []
    visited = Set.new
    temp_visited = Set.new

    folders_by_id = folders.index_by { |f| f[:id] }

    visit = lambda do |folder|
      return if visited.include?(folder[:id])
      return if temp_visited.include?(folder[:id])

      temp_visited.add(folder[:id])

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

  def build_message(folders_created, folders_updated, docs_converted, docs_created, docs_uploaded, docs_skipped, errors)
    parts = []
    parts << "#{folders_created} folder(s) created" if folders_created > 0
    parts << "#{folders_updated} folder(s) updated" if folders_updated > 0
    parts << "#{docs_converted} document(s) converted to native" if docs_converted > 0
    parts << "#{docs_created} document(s) created as native" if docs_created > 0
    parts << "#{docs_uploaded} file(s) uploaded" if docs_uploaded > 0
    parts << "#{docs_skipped} document(s) skipped (already imported)" if docs_skipped > 0
    parts << "#{errors.length} error(s)" if errors.any?

    if parts.empty?
      "No documents to import"
    else
      "Import complete: #{parts.join(', ')}"
    end
  end
end
