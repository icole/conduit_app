# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class GoogleDriveNativeImportServiceTest < ActiveSupport::TestCase
  setup do
    @community = communities(:crow_woods)
    ActsAsTenant.current_tenant = @community

    @mock_api = Minitest::Mock.new
    @root_folder_id = "test_folder_id"
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  def mock_drive_folder(id:, name:, parent_id: nil)
    {
      id: id,
      name: name,
      parents: parent_id ? [ parent_id ] : nil
    }
  end

  def mock_drive_file(id:, name:, parent_id:, mime_type: "application/vnd.google-apps.document", web_link: nil, created_at: nil, updated_at: nil)
    {
      id: id,
      name: name,
      mime_type: mime_type,
      web_link: web_link || default_web_link(id, mime_type),
      parents: [ parent_id ],
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def default_web_link(id, mime_type)
    if google_native_mime?(mime_type)
      "https://docs.google.com/document/d/#{id}/edit"
    else
      "https://drive.google.com/file/d/#{id}/view"
    end
  end

  def google_native_mime?(mime_type)
    %w[
      application/vnd.google-apps.document
      application/vnd.google-apps.spreadsheet
      application/vnd.google-apps.presentation
    ].include?(mime_type)
  end

  def non_exportable_mime?(mime_type)
    %w[
      application/vnd.google-apps.form
      application/vnd.google-apps.map
      application/vnd.google-apps.site
      application/vnd.google-apps.fusiontable
      application/vnd.google-apps.jam
      application/vnd.google-apps.shortcut
    ].include?(mime_type)
  end

  def default_web_link_for_form(id)
    "https://docs.google.com/forms/d/#{id}/edit"
  end

  test "converts existing google_drive document to native with HTML content" do
    existing_doc = Document.create!(
      title: "Board Minutes",
      google_drive_url: "https://docs.google.com/document/d/file_1/edit",
      storage_type: :google_drive,
      document_type: "Document",
      community: @community
    )

    drive_files = [
      mock_drive_file(id: "file_1", name: "Board Minutes", parent_id: @root_folder_id)
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<h1>Board Minutes</h1>" }, [ "file_1" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      existing_doc.reload
      assert_equal "native", existing_doc.storage_type
      assert_equal "<h1>Board Minutes</h1>", existing_doc.content
      assert_equal "Document", existing_doc.document_type
      assert_equal "https://docs.google.com/document/d/file_1/edit", existing_doc.google_drive_url
      assert_equal 1, result[:docs_converted]
    end

    @mock_api.verify
  end

  test "creates new native document for file not yet in system" do
    drive_files = [
      mock_drive_file(id: "new_file_1", name: "Community Policy", parent_id: @root_folder_id)
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>Policy content</p>" }, [ "new_file_1" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      doc = Document.find_by(google_drive_url: "https://docs.google.com/document/d/new_file_1/edit")
      assert_not_nil doc
      assert_equal "Community Policy", doc.title
      assert_equal "native", doc.storage_type
      assert_equal "<p>Policy content</p>", doc.content
      assert_equal "Document", doc.document_type
      assert_equal 1, result[:docs_created]
    end

    @mock_api.verify
  end

  test "skips already-imported native documents (idempotent)" do
    Document.create!(
      title: "Already Imported",
      google_drive_url: "https://docs.google.com/document/d/existing_native/edit",
      storage_type: :native,
      content: "<p>Already here</p>",
      community: @community
    )

    drive_files = [
      mock_drive_file(id: "existing_native", name: "Already Imported", parent_id: @root_folder_id)
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      initial_count = Document.count

      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert_equal initial_count, Document.count
      assert_equal 1, result[:docs_skipped]
    end

    @mock_api.verify
  end

  test "re-exports native doc when Drive updated_at is newer" do
    old_updated_at = Time.utc(2024, 1, 1, 0, 0, 0)
    drive_modified = Time.utc(2025, 6, 15, 12, 0, 0)

    doc = Document.create!(
      title: "Already Imported",
      google_drive_url: "https://docs.google.com/document/d/sync_ts/edit",
      storage_type: :native,
      content: "<p>Old content</p>",
      community: @community
    )
    doc.update_columns(updated_at: old_updated_at)

    drive_files = [
      mock_drive_file(id: "sync_ts", name: "Already Imported", parent_id: @root_folder_id,
                      updated_at: drive_modified)
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>Updated content</p>" }, [ "sync_ts" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert_equal 1, result[:docs_updated]
      assert_equal 0, result[:docs_skipped]

      doc.reload
      assert_equal "<p>Updated content</p>", doc.content
      assert_equal drive_modified, doc.updated_at
    end

    @mock_api.verify
  end

  test "skips native doc when Drive updated_at matches (no API calls)" do
    matching_time = Time.utc(2024, 6, 1, 10, 0, 0)

    doc = Document.create!(
      title: "Already Imported",
      google_drive_url: "https://docs.google.com/document/d/no_sync_ts/edit",
      storage_type: :native,
      content: "<p>Content</p>",
      community: @community
    )
    doc.update_columns(updated_at: matching_time)

    drive_files = [
      mock_drive_file(id: "no_sync_ts", name: "Already Imported", parent_id: @root_folder_id,
                      updated_at: matching_time)
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    # No export_as_html expectation — should not be called

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert_equal 1, result[:docs_skipped]
      assert_equal 0, result[:docs_updated]

      doc.reload
      assert_equal "<p>Content</p>", doc.content
      assert_equal matching_time, doc.updated_at
    end

    @mock_api.verify
  end

  test "re-downloads uploaded file when Drive updated_at is newer" do
    old_updated_at = Time.utc(2024, 1, 1, 0, 0, 0)
    drive_modified = Time.utc(2025, 6, 15, 12, 0, 0)

    doc = Document.new(
      title: "Budget.pdf",
      google_drive_url: "https://drive.google.com/file/d/redownload_pdf/view",
      storage_type: :uploaded,
      document_type: "PDF",
      community: @community
    )
    doc.file.attach(io: StringIO.new("old pdf content"), filename: "Budget.pdf", content_type: "application/pdf")
    doc.save!
    doc.update_columns(updated_at: old_updated_at)

    drive_files = [
      mock_drive_file(id: "redownload_pdf", name: "Budget.pdf", parent_id: @root_folder_id,
                      mime_type: "application/pdf", updated_at: drive_modified)
    ]

    new_pdf_content = StringIO.new("new pdf content")

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:download_file, {
      status: :success, content: new_pdf_content, name: "Budget.pdf", mime_type: "application/pdf"
    }, [ "redownload_pdf" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert_equal 1, result[:docs_updated]
      assert_equal 0, result[:docs_skipped]

      doc.reload
      assert_equal drive_modified, doc.updated_at
      assert doc.file.attached?
    end

    @mock_api.verify
  end

  test "re-exports uploaded spreadsheet (XLSX fallback) when Drive updated_at is newer" do
    old_updated_at = Time.utc(2024, 1, 1, 0, 0, 0)
    drive_modified = Time.utc(2025, 6, 15, 12, 0, 0)
    xlsx_mime = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    doc = Document.new(
      title: "Budget Sheet",
      google_drive_url: "https://docs.google.com/spreadsheets/d/reexport_sheet/edit",
      storage_type: :uploaded,
      document_type: "Excel Spreadsheet",
      community: @community
    )
    doc.file.attach(io: StringIO.new("old xlsx"), filename: "Budget Sheet.xlsx", content_type: xlsx_mime)
    doc.save!
    doc.update_columns(updated_at: old_updated_at)

    drive_files = [
      mock_drive_file(id: "reexport_sheet", name: "Budget Sheet", parent_id: @root_folder_id,
                      mime_type: "application/vnd.google-apps.spreadsheet",
                      web_link: "https://docs.google.com/spreadsheets/d/reexport_sheet/edit",
                      updated_at: drive_modified)
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<table>Updated</table>" }, [ "reexport_sheet" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert_equal 1, result[:docs_updated]
      assert_equal 0, result[:docs_skipped]

      doc.reload
      assert_equal "<table>Updated</table>", doc.content
      assert_equal "native", doc.storage_type
      assert_equal drive_modified, doc.updated_at
    end

    @mock_api.verify
  end

  test "creates folder structure matching Drive hierarchy" do
    drive_folders = [
      mock_drive_folder(id: "folder_1", name: "Board Documents", parent_id: @root_folder_id),
      mock_drive_folder(id: "folder_2", name: "2024 Archive", parent_id: "folder_1")
    ]

    @mock_api.expect(:list_folder_tree, { folders: drive_folders, status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: [], status: :success }, [ Array ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]

      board_docs = DocumentFolder.find_by(google_drive_id: "folder_1")
      assert_not_nil board_docs
      assert_equal "Board Documents", board_docs.name
      assert_nil board_docs.parent_id

      archive = DocumentFolder.find_by(google_drive_id: "folder_2")
      assert_not_nil archive
      assert_equal "2024 Archive", archive.name
      assert_equal board_docs.id, archive.parent_id

      assert_equal 2, result[:folders_created]
    end

    @mock_api.verify
  end

  test "handles export errors gracefully and continues" do
    drive_files = [
      mock_drive_file(id: "good_file", name: "Good Doc", parent_id: @root_folder_id),
      mock_drive_file(id: "bad_file", name: "Bad Doc", parent_id: @root_folder_id)
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>Good</p>" }, [ "good_file" ])
    @mock_api.expect(:export_as_html, { status: :client_error, error: "Export failed" }, [ "bad_file" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal 1, result[:docs_created]
      assert_equal 1, result[:errors].length
      assert_includes result[:errors].first, "Bad Doc"
    end

    @mock_api.verify
  end

  test "returns accurate summary counts" do
    # Existing google_drive doc to convert
    Document.create!(
      title: "To Convert",
      google_drive_url: "https://docs.google.com/document/d/convert_me/edit",
      storage_type: :google_drive,
      document_type: "Document",
      community: @community
    )

    # Existing native doc to skip
    Document.create!(
      title: "Already Native",
      google_drive_url: "https://docs.google.com/document/d/already_native/edit",
      storage_type: :native,
      content: "<p>Done</p>",
      community: @community
    )

    drive_folders = [
      mock_drive_folder(id: "folder_a", name: "Folder A", parent_id: @root_folder_id)
    ]

    drive_files = [
      mock_drive_file(id: "convert_me", name: "To Convert", parent_id: @root_folder_id),
      mock_drive_file(id: "already_native", name: "Already Native", parent_id: @root_folder_id),
      mock_drive_file(id: "brand_new", name: "Brand New", parent_id: "folder_a")
    ]

    @mock_api.expect(:list_folder_tree, { folders: drive_folders, status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>Converted</p>" }, [ "convert_me" ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>New doc</p>" }, [ "brand_new" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal 1, result[:folders_created]
      assert_equal 0, result[:folders_updated]
      assert_equal 1, result[:docs_converted]
      assert_equal 1, result[:docs_created]
      assert_equal 1, result[:docs_skipped]
      assert_empty result[:errors]
    end

    @mock_api.verify
  end

  # --- Uploaded file type tests ---

  test "downloads and attaches a PDF as an uploaded document" do
    drive_files = [
      mock_drive_file(id: "pdf_file_1", name: "Budget Report.pdf", parent_id: @root_folder_id,
                      mime_type: "application/pdf")
    ]

    pdf_content = StringIO.new("%PDF-1.4 fake pdf content")

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:download_file, {
      status: :success, content: pdf_content, name: "Budget Report.pdf", mime_type: "application/pdf"
    }, [ "pdf_file_1" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal 1, result[:docs_uploaded]

      doc = Document.find_by(google_drive_url: "https://drive.google.com/file/d/pdf_file_1/view")
      assert_not_nil doc
      assert_equal "Budget Report.pdf", doc.title
      assert_equal "uploaded", doc.storage_type
      assert_equal "PDF", doc.document_type
      assert doc.file.attached?
    end

    @mock_api.verify
  end

  test "skips already-uploaded documents (idempotent)" do
    existing_doc = Document.new(
      title: "Existing PDF",
      google_drive_url: "https://drive.google.com/file/d/existing_pdf/view",
      storage_type: :uploaded,
      document_type: "PDF",
      community: @community
    )
    existing_doc.file.attach(io: StringIO.new("fake pdf"), filename: "existing.pdf", content_type: "application/pdf")
    existing_doc.save!

    drive_files = [
      mock_drive_file(id: "existing_pdf", name: "Existing PDF", parent_id: @root_folder_id,
                      mime_type: "application/pdf")
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      initial_count = Document.count

      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert_equal initial_count, Document.count
      assert_equal 1, result[:docs_skipped]
    end

    @mock_api.verify
  end

  test "handles download errors gracefully for uploaded files" do
    drive_files = [
      mock_drive_file(id: "good_pdf", name: "Good PDF", parent_id: @root_folder_id,
                      mime_type: "application/pdf"),
      mock_drive_file(id: "bad_pdf", name: "Bad PDF", parent_id: @root_folder_id,
                      mime_type: "application/pdf")
    ]

    pdf_content = StringIO.new("fake pdf")

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:download_file, {
      status: :success, content: pdf_content, name: "Good PDF", mime_type: "application/pdf"
    }, [ "good_pdf" ])
    @mock_api.expect(:download_file, {
      status: :client_error, error: "Download failed"
    }, [ "bad_pdf" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal 1, result[:docs_uploaded]
      assert_equal 1, result[:errors].length
      assert_includes result[:errors].first, "Bad PDF"
    end

    @mock_api.verify
  end

  test "sets correct document_type for various uploaded mime types" do
    drive_files = [
      mock_drive_file(id: "word_file", name: "Report.docx", parent_id: @root_folder_id,
                      mime_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
      mock_drive_file(id: "excel_file", name: "Budget.xlsx", parent_id: @root_folder_id,
                      mime_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
      mock_drive_file(id: "ppt_file", name: "Slides.pptx", parent_id: @root_folder_id,
                      mime_type: "application/vnd.openxmlformats-officedocument.presentationml.presentation")
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])

    %w[word_file excel_file ppt_file].each do |file_id|
      content = StringIO.new("fake content for #{file_id}")
      @mock_api.expect(:download_file, {
        status: :success, content: content, name: "#{file_id}.bin", mime_type: "application/octet-stream"
      }, [ file_id ])
    end

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal 3, result[:docs_uploaded]

      word_doc = Document.find_by(google_drive_url: "https://drive.google.com/file/d/word_file/view")
      assert_equal "Word Document", word_doc.document_type

      excel_doc = Document.find_by(google_drive_url: "https://drive.google.com/file/d/excel_file/view")
      assert_equal "Excel Spreadsheet", excel_doc.document_type

      ppt_doc = Document.find_by(google_drive_url: "https://drive.google.com/file/d/ppt_file/view")
      assert_equal "PowerPoint", ppt_doc.document_type
    end

    @mock_api.verify
  end

  test "returns accurate summary counts including uploaded files and updated docs" do
    # Existing google_drive doc to convert
    Document.create!(
      title: "To Convert",
      google_drive_url: "https://docs.google.com/document/d/convert_me/edit",
      storage_type: :google_drive,
      document_type: "Document",
      community: @community
    )

    # Existing native doc with matching timestamp — skip
    matching_time = Time.utc(2024, 6, 1, 10, 0, 0)
    skip_doc = Document.create!(
      title: "Already Native",
      google_drive_url: "https://docs.google.com/document/d/already_native/edit",
      storage_type: :native,
      content: "<p>Done</p>",
      community: @community
    )
    skip_doc.update_columns(updated_at: matching_time)

    # Existing native doc with older timestamp — should be updated
    old_time = Time.utc(2023, 1, 1, 0, 0, 0)
    update_doc = Document.create!(
      title: "Stale Native",
      google_drive_url: "https://docs.google.com/document/d/stale_native/edit",
      storage_type: :native,
      content: "<p>Old</p>",
      community: @community
    )
    update_doc.update_columns(updated_at: old_time)

    drive_folders = [
      mock_drive_folder(id: "folder_a", name: "Folder A", parent_id: @root_folder_id)
    ]

    drive_files = [
      mock_drive_file(id: "convert_me", name: "To Convert", parent_id: @root_folder_id),
      mock_drive_file(id: "already_native", name: "Already Native", parent_id: @root_folder_id, updated_at: matching_time),
      mock_drive_file(id: "stale_native", name: "Stale Native", parent_id: @root_folder_id, updated_at: Time.utc(2025, 6, 1)),
      mock_drive_file(id: "brand_new", name: "Brand New", parent_id: "folder_a"),
      mock_drive_file(id: "a_pdf", name: "A PDF", parent_id: @root_folder_id, mime_type: "application/pdf")
    ]

    pdf_content = StringIO.new("fake pdf")

    @mock_api.expect(:list_folder_tree, { folders: drive_folders, status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>Converted</p>" }, [ "convert_me" ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>Refreshed</p>" }, [ "stale_native" ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>New doc</p>" }, [ "brand_new" ])
    @mock_api.expect(:download_file, {
      status: :success, content: pdf_content, name: "A PDF", mime_type: "application/pdf"
    }, [ "a_pdf" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal 1, result[:folders_created]
      assert_equal 0, result[:folders_updated]
      assert_equal 1, result[:docs_converted]
      assert_equal 1, result[:docs_created]
      assert_equal 1, result[:docs_skipped]
      assert_equal 1, result[:docs_uploaded]
      assert_equal 1, result[:docs_updated]
      assert_empty result[:errors]
      assert_includes result[:message], "1 document(s) updated"
    end

    @mock_api.verify
  end

  test "requires root folder ID to be configured" do
    community_without_drive = communities(:other_community)
    ActsAsTenant.current_tenant = community_without_drive

    original_env = ENV["GOOGLE_DRIVE_FOLDER_ID"]
    ENV["GOOGLE_DRIVE_FOLDER_ID"] = nil

    service = GoogleDriveNativeImportService.new(community_without_drive)
    result = service.import!

    assert_not result[:success]
    assert_includes result[:message], "No Google Drive folder configured"
  ensure
    ENV["GOOGLE_DRIVE_FOLDER_ID"] = original_env
  end

  # --- Timestamp preservation tests ---

  test "new native document preserves Drive created_at and updated_at timestamps" do
    drive_created = Time.utc(2024, 1, 15, 10, 30, 0)
    drive_modified = Time.utc(2024, 6, 20, 14, 0, 0)

    drive_files = [
      mock_drive_file(id: "ts_file_1", name: "Timestamped Doc", parent_id: @root_folder_id,
                      created_at: drive_created, updated_at: drive_modified)
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>Content</p>" }, [ "ts_file_1" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert_equal 1, result[:docs_created]

      doc = Document.find_by(google_drive_url: "https://docs.google.com/document/d/ts_file_1/edit")
      assert_not_nil doc
      assert_equal drive_created, doc.created_at
      assert_equal drive_modified, doc.updated_at
    end

    @mock_api.verify
  end

  test "converted document preserves Drive created_at and updated_at timestamps" do
    drive_created = Time.utc(2023, 3, 10, 8, 0, 0)
    drive_modified = Time.utc(2025, 1, 5, 16, 45, 0)

    existing_doc = Document.create!(
      title: "To Convert TS",
      google_drive_url: "https://docs.google.com/document/d/ts_convert/edit",
      storage_type: :google_drive,
      document_type: "Document",
      community: @community
    )

    drive_files = [
      mock_drive_file(id: "ts_convert", name: "To Convert TS", parent_id: @root_folder_id,
                      created_at: drive_created, updated_at: drive_modified)
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>Converted</p>" }, [ "ts_convert" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert_equal 1, result[:docs_converted]

      existing_doc.reload
      assert_equal drive_created, existing_doc.created_at
      assert_equal drive_modified, existing_doc.updated_at
    end

    @mock_api.verify
  end

  test "uploaded document preserves Drive created_at and updated_at timestamps" do
    drive_created = Time.utc(2024, 5, 1, 12, 0, 0)
    drive_modified = Time.utc(2024, 8, 15, 9, 30, 0)

    drive_files = [
      mock_drive_file(id: "ts_pdf", name: "Timestamped.pdf", parent_id: @root_folder_id,
                      mime_type: "application/pdf",
                      created_at: drive_created, updated_at: drive_modified)
    ]

    pdf_content = StringIO.new("%PDF-1.4 fake")

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:download_file, {
      status: :success, content: pdf_content, name: "Timestamped.pdf", mime_type: "application/pdf"
    }, [ "ts_pdf" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert_equal 1, result[:docs_uploaded]

      doc = Document.find_by(google_drive_url: "https://drive.google.com/file/d/ts_pdf/view")
      assert_not_nil doc
      assert_equal drive_created, doc.created_at
      assert_equal drive_modified, doc.updated_at
    end

    @mock_api.verify
  end

  # --- Non-importable Google-native type tests ---

  test "skips Google Forms and counts them in docs_skipped" do
    drive_files = [
      mock_drive_file(id: "form_1", name: "Community Survey", parent_id: @root_folder_id,
                      mime_type: "application/vnd.google-apps.form",
                      web_link: "https://docs.google.com/forms/d/form_1/edit"),
      mock_drive_file(id: "doc_1", name: "Regular Doc", parent_id: @root_folder_id)
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>Doc content</p>" }, [ "doc_1" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      initial_count = Document.count

      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal 1, result[:docs_skipped]
      assert_equal 1, result[:docs_created]
      assert_equal initial_count + 1, Document.count
      assert_nil Document.find_by(google_drive_url: "https://docs.google.com/forms/d/form_1/edit")
    end

    @mock_api.verify
  end

  test "skips all non-importable Google-native types" do
    non_importable_types = %w[
      application/vnd.google-apps.form
      application/vnd.google-apps.map
      application/vnd.google-apps.site
      application/vnd.google-apps.fusiontable
      application/vnd.google-apps.jam
      application/vnd.google-apps.shortcut
    ]

    drive_files = non_importable_types.each_with_index.map do |mime_type, i|
      mock_drive_file(id: "skip_#{i}", name: "Skip #{i}", parent_id: @root_folder_id,
                      mime_type: mime_type,
                      web_link: "https://drive.google.com/file/d/skip_#{i}/view")
    end

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      initial_count = Document.count

      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal non_importable_types.length, result[:docs_skipped]
      assert_equal 0, result[:docs_created]
      assert_equal 0, result[:docs_uploaded]
      assert_equal initial_count, Document.count
    end

    @mock_api.verify
  end

  # --- Spreadsheet XLSX fallback tests ---

  test "falls back to XLSX when spreadsheet HTML export fails for new document" do
    drive_files = [
      mock_drive_file(id: "sheet_1", name: "Budget Spreadsheet", parent_id: @root_folder_id,
                      mime_type: "application/vnd.google-apps.spreadsheet",
                      web_link: "https://docs.google.com/spreadsheets/d/sheet_1/edit")
    ]

    xlsx_content = StringIO.new("fake xlsx content")

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :client_error, error: "conversion not supported" }, [ "sheet_1" ])
    @mock_api.expect(:export_as_xlsx, {
      status: :success, content: xlsx_content, name: "Budget Spreadsheet.xlsx",
      mime_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    }, [ "sheet_1" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal 1, result[:docs_uploaded]
      assert_equal 0, result[:docs_created]

      doc = Document.find_by(google_drive_url: "https://docs.google.com/spreadsheets/d/sheet_1/edit")
      assert_not_nil doc
      assert_equal "uploaded", doc.storage_type
      assert_equal "Excel Spreadsheet", doc.document_type
      assert doc.file.attached?
    end

    @mock_api.verify
  end

  test "falls back to XLSX when spreadsheet HTML export fails for existing google_drive document" do
    existing_doc = Document.create!(
      title: "Old Sheet",
      google_drive_url: "https://docs.google.com/spreadsheets/d/sheet_convert/edit",
      storage_type: :google_drive,
      document_type: "Spreadsheet",
      community: @community
    )

    drive_files = [
      mock_drive_file(id: "sheet_convert", name: "Old Sheet", parent_id: @root_folder_id,
                      mime_type: "application/vnd.google-apps.spreadsheet",
                      web_link: "https://docs.google.com/spreadsheets/d/sheet_convert/edit")
    ]

    xlsx_content = StringIO.new("fake xlsx content")

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :client_error, error: "conversion not supported" }, [ "sheet_convert" ])
    @mock_api.expect(:export_as_xlsx, {
      status: :success, content: xlsx_content, name: "Old Sheet.xlsx",
      mime_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    }, [ "sheet_convert" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal 1, result[:docs_uploaded]
      assert_equal 0, result[:docs_converted]

      existing_doc.reload
      assert_equal "uploaded", existing_doc.storage_type
      assert_equal "Excel Spreadsheet", existing_doc.document_type
      assert existing_doc.file.attached?
    end

    @mock_api.verify
  end

  test "reports error when spreadsheet XLSX fallback also fails" do
    drive_files = [
      mock_drive_file(id: "sheet_fail", name: "Failing Sheet", parent_id: @root_folder_id,
                      mime_type: "application/vnd.google-apps.spreadsheet",
                      web_link: "https://docs.google.com/spreadsheets/d/sheet_fail/edit")
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :client_error, error: "conversion not supported" }, [ "sheet_fail" ])
    @mock_api.expect(:export_as_xlsx, { status: :client_error, error: "XLSX export also failed" }, [ "sheet_fail" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal 1, result[:errors].length
      assert_includes result[:errors].first, "Failing Sheet"
    end

    @mock_api.verify
  end

  test "reimport_document! re-exports a native document from Google Drive" do
    doc = Document.create!(
      title: "Old Content",
      google_drive_url: "https://docs.google.com/document/d/reimport_test/edit",
      storage_type: :native,
      content: "<p>Old content without images</p>",
      community: @community
    )

    @mock_api.expect(:export_as_html, {
      status: :success,
      content: "<body><p>New content with images</p></body>"
    }, [ "reimport_test" ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.reimport_document!(doc)

      assert result[:success]
      doc.reload
      assert_includes doc.content, "New content with images"
    end

    @mock_api.verify
  end

  test "reimport_document! fails for document without google_drive_url" do
    doc = Document.create!(
      title: "Native Only",
      storage_type: :native,
      content: "<p>Content</p>",
      community: @community
    )

    service = GoogleDriveNativeImportService.new(@community)
    result = service.reimport_document!(doc)

    assert_not result[:success]
    assert_equal "Document has no Google Drive URL", result[:error]
  end

  test "reimport_document! fails for non-Google document types" do
    doc = Document.new(
      title: "PDF File",
      google_drive_url: "https://drive.google.com/file/d/pdf_file/view",
      storage_type: :uploaded,
      document_type: "PDF",
      community: @community
    )
    doc.file.attach(io: StringIO.new("pdf content"), filename: "test.pdf", content_type: "application/pdf")
    doc.save!

    service = GoogleDriveNativeImportService.new(@community)
    result = service.reimport_document!(doc)

    assert_not result[:success]
    assert_equal "Only native documents can be re-imported", result[:error]
  end
end
