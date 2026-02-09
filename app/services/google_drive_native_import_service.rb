# frozen_string_literal: true

# Service responsible for importing Google Drive documents as native documents with HTML content.
# This is a one-way import: reads from Drive, creates/converts native documents, never modifies Drive.
class GoogleDriveNativeImportService
  def initialize(community)
    @community = community
    @root_folder_id = community.google_drive_folder_id || ENV["GOOGLE_DRIVE_FOLDER_ID"]
  end

  # Re-import a single document from Google Drive, bypassing timestamp checks.
  # Useful for picking up images after the image download feature was added.
  def reimport_document!(document)
    return { success: false, error: "Document has no Google Drive URL" } if document.google_drive_url.blank?
    return { success: false, error: "Only native documents can be re-imported" } unless document.native?

    file_id = document.google_drive_file_id
    return { success: false, error: "Could not extract file ID from Google Drive URL" } if file_id.blank?

    ActsAsTenant.with_tenant(@community) do
      export_result = api.export_as_html(file_id)

      unless export_result[:status] == :success
        return { success: false, error: "Failed to export document: #{export_result[:error]}" }
      end

      # Clear existing images before re-importing (to avoid duplicates)
      document.images.purge if document.images.attached?

      document.update!(content: clean_html(export_result[:content], document))

      { success: true, message: "Document re-imported successfully" }
    end
  rescue StandardError => e
    Rails.logger.error("[DriveImport] Error re-importing document #{document.id}: #{e.message}")
    { success: false, error: e.message }
  end

  def import!
    return { success: false, message: "No Google Drive folder configured" } unless @root_folder_id.present?

    ActsAsTenant.with_tenant(@community) do
      # Fetch folder structure from Drive
      folder_result = api.list_folder_tree(@root_folder_id)
      return { success: false, message: "Failed to fetch folders: #{folder_result[:error]}" } unless folder_result[:status] == :success

      drive_folders = folder_result[:folders]

      # Sync folders (create/update DocumentFolder records)
      folders_created, folders_updated = sync_folders(drive_folders)

      # Build list of all folder IDs to fetch files from
      all_folder_ids = [ @root_folder_id ] + drive_folders.map { |f| f[:id] }

      # Fetch files
      files_result = api.list_files_in_folders(all_folder_ids)
      return { success: false, message: "Failed to fetch files: #{files_result[:error]}" } unless files_result[:status] == :success

      # Import files as native or uploaded documents
      docs_converted, docs_created, docs_uploaded, docs_skipped, docs_updated, errors = import_files(files_result[:files], drive_folders)

      {
        success: true,
        message: build_message(folders_created, folders_updated, docs_converted, docs_created, docs_uploaded, docs_skipped, docs_updated, errors),
        folders_created: folders_created,
        folders_updated: folders_updated,
        docs_converted: docs_converted,
        docs_created: docs_created,
        docs_uploaded: docs_uploaded,
        docs_skipped: docs_skipped,
        docs_updated: docs_updated,
        errors: errors
      }
    end
  end

  private

  def api
    @api ||= GoogleDriveApiService.from_service_account
  end

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
    docs_updated = 0
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

      drive_timestamps = { created_at: drive_file[:created_at], updated_at: drive_file[:updated_at] }

      if skip_mime_type?(drive_file[:mime_type])
        Rails.logger.info("[DriveImport] Skipping image file: #{drive_file[:name]}")
        docs_skipped += 1
      elsif existing&.native? || existing&.uploaded?
        # Already imported — re-import if Drive updated_at differs, otherwise skip
        if drive_timestamps[:updated_at] && existing.updated_at != drive_timestamps[:updated_at]
          result = if google_doc_type?(drive_file[:mime_type])
            export_and_update(existing, file_id, drive_file[:name], drive_file[:mime_type], local_folder_id, drive_timestamps)
          else
            download_and_update(existing, file_id, drive_file[:name], drive_file[:mime_type], local_folder_id, drive_timestamps)
          end
          if result == :success || result == :xlsx_fallback
            docs_updated += 1
          else
            errors << result
          end
        else
          Rails.logger.info("[DriveImport] Skipping already-imported: #{drive_file[:name]}")
          docs_skipped += 1
        end
      elsif google_native_skip_type?(drive_file[:mime_type])
        # Non-importable Google-native type (Forms, Maps, Sites, etc.) — skip
        Rails.logger.info("[DriveImport] Skipping non-importable type: #{drive_file[:name]} (#{drive_file[:mime_type]})")
        docs_skipped += 1
      elsif google_doc_type?(drive_file[:mime_type])
        # Google-native file — export as HTML
        if existing&.google_drive?
          result = export_and_update(existing, file_id, drive_file[:name], drive_file[:mime_type], local_folder_id, drive_timestamps)
          case result
          when :success then docs_converted += 1
          when :xlsx_fallback then docs_uploaded += 1
          else errors << result
          end
        else
          result = export_and_create(web_link, file_id, drive_file[:name], drive_file[:mime_type], local_folder_id, drive_timestamps)
          case result
          when :success then docs_created += 1
          when :xlsx_fallback then docs_uploaded += 1
          else errors << result
          end
        end
      else
        # Non-Google-native file — download and attach
        result = download_and_create(web_link, file_id, drive_file[:name], drive_file[:mime_type], local_folder_id, drive_timestamps)
        if result == :success
          docs_uploaded += 1
        else
          errors << result
        end
      end
    end

    [ docs_converted, docs_created, docs_uploaded, docs_skipped, docs_updated, errors ]
  end

  def export_and_update(document, file_id, name, mime_type, local_folder_id, drive_timestamps)
    Rails.logger.info("[DriveImport] Converting to native: #{name}")
    export_result = api.export_as_html(file_id)

    unless export_result[:status] == :success
      # For spreadsheets, fall back to XLSX export as an uploaded document
      if mime_type == "application/vnd.google-apps.spreadsheet"
        return xlsx_fallback_update(document, file_id, name, local_folder_id, drive_timestamps)
      end

      msg = "Failed to export '#{name}': #{export_result[:error]}"
      Rails.logger.error("[DriveImport] #{msg}")
      return msg
    end

    document.update!(
      storage_type: :native,
      content: clean_html(export_result[:content], document),
      document_type: document_type_from_mime(mime_type),
      document_folder_id: local_folder_id
    )
    apply_drive_timestamps(document, drive_timestamps)
    :success
  end

  def export_and_create(web_link, file_id, name, mime_type, local_folder_id, drive_timestamps)
    Rails.logger.info("[DriveImport] Creating native doc: #{name}")
    export_result = api.export_as_html(file_id)

    unless export_result[:status] == :success
      # For spreadsheets, fall back to XLSX export as an uploaded document
      if mime_type == "application/vnd.google-apps.spreadsheet"
        return xlsx_fallback_create(web_link, file_id, name, local_folder_id, drive_timestamps)
      end

      msg = "Failed to export '#{name}': #{export_result[:error]}"
      Rails.logger.error("[DriveImport] #{msg}")
      return msg
    end

    # Create document first with placeholder content
    doc = Document.create!(
      title: name,
      google_drive_url: web_link,
      storage_type: :native,
      content: "",
      document_type: document_type_from_mime(mime_type),
      document_folder_id: local_folder_id,
      community: @community
    )

    # Now clean HTML with image support (images will be attached to doc)
    doc.update!(content: clean_html(export_result[:content], doc))

    apply_drive_timestamps(doc, drive_timestamps)
    :success
  end

  def download_and_create(web_link, file_id, name, mime_type, local_folder_id, drive_timestamps)
    Rails.logger.info("[DriveImport] Downloading uploaded file: #{name}")
    download_result = api.download_file(file_id)

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
    apply_drive_timestamps(doc, drive_timestamps)
    :success
  end

  def download_and_update(document, file_id, name, mime_type, local_folder_id, drive_timestamps)
    Rails.logger.info("[DriveImport] Re-downloading uploaded file: #{name}")
    download_result = api.download_file(file_id)

    unless download_result[:status] == :success
      msg = "Failed to download '#{name}': #{download_result[:error]}"
      Rails.logger.error("[DriveImport] #{msg}")
      return msg
    end

    document.file.attach(
      io: download_result[:content],
      filename: name,
      content_type: download_result[:mime_type]
    )
    document.update!(
      document_type: document_type_from_mime(mime_type),
      document_folder_id: local_folder_id
    )
    apply_drive_timestamps(document, drive_timestamps)
    :success
  end

  def apply_drive_timestamps(document, timestamps)
    columns = {}
    columns[:created_at] = timestamps[:created_at] if timestamps[:created_at]
    columns[:updated_at] = timestamps[:updated_at] if timestamps[:updated_at]
    document.update_columns(columns) if columns.any?
  end

  def extract_file_id(url)
    return nil if url.blank?

    match = url.match(%r{/d/([a-zA-Z0-9_-]+)})
    match&.[](1)
  end

  def document_type_from_mime(mime_type)
    Document.document_type_from_mime(mime_type)
  end

  def google_doc_type?(mime_type)
    %w[
      application/vnd.google-apps.document
      application/vnd.google-apps.spreadsheet
      application/vnd.google-apps.presentation
    ].include?(mime_type)
  end

  def skip_mime_type?(mime_type)
    mime_type&.start_with?("image/")
  end

  def google_native_skip_type?(mime_type)
    %w[
      application/vnd.google-apps.form
      application/vnd.google-apps.map
      application/vnd.google-apps.site
      application/vnd.google-apps.fusiontable
      application/vnd.google-apps.jam
      application/vnd.google-apps.shortcut
    ].include?(mime_type)
  end

  # Clean Google Drive exported HTML for Tiptap compatibility
  # If a document is provided, Google-hosted images will be downloaded and attached
  def clean_html(html, document = nil)
    return "" if html.blank?

    doc = Nokogiri::HTML(html)
    body = doc.at_css("body")
    return "" unless body

    # Remove style, script tags
    body.css("style, script").remove

    # Remove Google's tracking images
    body.css("img[src*='google.com/a/']").remove

    # Process images - download Google-hosted ones and re-host them
    if document
      images = body.css("img")
      Rails.logger.info("[DriveImport] Found #{images.length} images in document #{document.id}")

      images.each do |img|
        src = img["src"]
        if src.blank?
          Rails.logger.info("[DriveImport] Skipping image with blank src")
          next
        end

        # Log first 100 chars of URL for debugging
        Rails.logger.info("[DriveImport] Processing image: #{src[0, 100]}...")

        if google_hosted_image?(src)
          Rails.logger.info("[DriveImport] Image is Google-hosted, downloading...")
          # Download and re-host the image
          new_url = download_and_attach_image(src, document)
          if new_url
            img["src"] = new_url
            Rails.logger.info("[DriveImport] Successfully attached image: #{new_url}")
          else
            # Failed to download - remove the broken image
            img.remove
            Rails.logger.warn("[DriveImport] Failed to download image, removed from content")
          end
        else
          Rails.logger.info("[DriveImport] Image is not Google-hosted, preserving as-is")
        end
      end
    end

    # Remove class/id attributes (they reference removed styles)
    body.traverse do |node|
      if node.element?
        node.remove_attribute("class")
        node.remove_attribute("id")
      end
    end

    body.inner_html
  end

  # Check if an image URL is hosted on Google's servers
  def google_hosted_image?(url)
    return false if url.blank?
    return false if url.start_with?("data:")

    google_hosts = [
      "googleusercontent.com",
      "ggpht.com",
      "docs.google.com"
    ]

    google_hosts.any? { |host| url.include?(host) }
  end

  # Download an image from Google and attach it to the document
  def download_and_attach_image(url, document)
    Rails.logger.info("[DriveImport] Downloading image: #{url}")

    response = download_image(url)
    return nil unless response

    # Generate a unique filename
    extension = content_type_to_extension(response[:content_type])
    filename = "image_#{SecureRandom.hex(8)}#{extension}"

    # Attach to document
    document.images.attach(
      io: response[:content],
      filename: filename,
      content_type: response[:content_type]
    )

    # Return the blob URL
    Rails.application.routes.url_helpers.rails_blob_path(
      document.images.last,
      only_path: true
    )
  rescue StandardError => e
    Rails.logger.error("[DriveImport] Failed to download image #{url}: #{e.message}")
    nil
  end

  def download_image(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      {
        content: StringIO.new(response.body),
        content_type: response["Content-Type"] || "image/png"
      }
    else
      Rails.logger.warn("[DriveImport] Image download failed with status #{response.code}: #{url}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("[DriveImport] Image download error: #{e.message}")
    nil
  end

  def content_type_to_extension(content_type)
    case content_type
    when /jpeg/i then ".jpg"
    when /png/i then ".png"
    when /gif/i then ".gif"
    when /webp/i then ".webp"
    when /svg/i then ".svg"
    else ".png"
    end
  end

  def xlsx_fallback_create(web_link, file_id, name, local_folder_id, drive_timestamps)
    Rails.logger.info("[DriveImport] HTML export failed for spreadsheet, falling back to XLSX: #{name}")
    xlsx_result = api.export_as_xlsx(file_id)

    unless xlsx_result[:status] == :success
      msg = "Failed to export '#{name}' as XLSX: #{xlsx_result[:error]}"
      Rails.logger.error("[DriveImport] #{msg}")
      return msg
    end

    xlsx_mime = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    doc = Document.new(
      title: name,
      google_drive_url: web_link,
      storage_type: :uploaded,
      document_type: document_type_from_mime(xlsx_mime),
      document_folder_id: local_folder_id,
      community: @community
    )
    doc.file.attach(
      io: xlsx_result[:content],
      filename: xlsx_result[:name],
      content_type: xlsx_mime
    )
    doc.save!
    apply_drive_timestamps(doc, drive_timestamps)
    :xlsx_fallback
  end

  def xlsx_fallback_update(document, file_id, name, local_folder_id, drive_timestamps)
    Rails.logger.info("[DriveImport] HTML export failed for spreadsheet, falling back to XLSX: #{name}")
    xlsx_result = api.export_as_xlsx(file_id)

    unless xlsx_result[:status] == :success
      msg = "Failed to export '#{name}' as XLSX: #{xlsx_result[:error]}"
      Rails.logger.error("[DriveImport] #{msg}")
      return msg
    end

    xlsx_mime = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    document.file.attach(
      io: xlsx_result[:content],
      filename: xlsx_result[:name],
      content_type: xlsx_mime
    )
    document.update!(
      storage_type: :uploaded,
      content: nil,
      document_type: document_type_from_mime(xlsx_mime),
      document_folder_id: local_folder_id
    )
    apply_drive_timestamps(document, drive_timestamps)
    :xlsx_fallback
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

  def build_message(folders_created, folders_updated, docs_converted, docs_created, docs_uploaded, docs_skipped, docs_updated, errors)
    parts = []
    parts << "#{folders_created} folder(s) created" if folders_created > 0
    parts << "#{folders_updated} folder(s) updated" if folders_updated > 0
    parts << "#{docs_converted} document(s) converted to native" if docs_converted > 0
    parts << "#{docs_created} document(s) created as native" if docs_created > 0
    parts << "#{docs_uploaded} file(s) uploaded" if docs_uploaded > 0
    parts << "#{docs_updated} document(s) updated" if docs_updated > 0
    parts << "#{docs_skipped} document(s) skipped (already imported)" if docs_skipped > 0
    parts << "#{errors.length} error(s)" if errors.any?

    if parts.empty?
      "No documents to import"
    else
      "Import complete: #{parts.join(', ')}"
    end
  end
end
