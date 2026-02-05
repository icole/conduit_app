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

  def mock_drive_file(id:, name:, parent_id:, mime_type: "application/vnd.google-apps.document", web_link: nil)
    {
      id: id,
      name: name,
      mime_type: mime_type,
      web_link: web_link || default_web_link(id, mime_type),
      parents: [ parent_id ]
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

  test "converts existing google_drive document to native with HTML content" do
    existing_doc = Document.create!(
      title: "Board Minutes",
      google_drive_url: "https://docs.google.com/document/d/file_1/edit",
      storage_type: :google_drive,
      document_type: "Google Doc",
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
      document_type: "Google Doc",
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
                      mime_type: "application/vnd.openxmlformats-officedocument.presentationml.presentation"),
      mock_drive_file(id: "image_file", name: "Photo.jpg", parent_id: @root_folder_id,
                      mime_type: "image/jpeg")
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])

    %w[word_file excel_file ppt_file image_file].each do |file_id|
      content = StringIO.new("fake content for #{file_id}")
      @mock_api.expect(:download_file, {
        status: :success, content: content, name: "#{file_id}.bin", mime_type: "application/octet-stream"
      }, [ file_id ])
    end

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveNativeImportService.new(@community)
      result = service.import!

      assert result[:success]
      assert_equal 4, result[:docs_uploaded]

      word_doc = Document.find_by(google_drive_url: "https://drive.google.com/file/d/word_file/view")
      assert_equal "Word Document", word_doc.document_type

      excel_doc = Document.find_by(google_drive_url: "https://drive.google.com/file/d/excel_file/view")
      assert_equal "Excel Spreadsheet", excel_doc.document_type

      ppt_doc = Document.find_by(google_drive_url: "https://drive.google.com/file/d/ppt_file/view")
      assert_equal "PowerPoint", ppt_doc.document_type

      image_doc = Document.find_by(google_drive_url: "https://drive.google.com/file/d/image_file/view")
      assert_equal "Image", image_doc.document_type
    end

    @mock_api.verify
  end

  test "returns accurate summary counts including uploaded files" do
    # Existing google_drive doc to convert
    Document.create!(
      title: "To Convert",
      google_drive_url: "https://docs.google.com/document/d/convert_me/edit",
      storage_type: :google_drive,
      document_type: "Google Doc",
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
      mock_drive_file(id: "brand_new", name: "Brand New", parent_id: "folder_a"),
      mock_drive_file(id: "a_pdf", name: "A PDF", parent_id: @root_folder_id, mime_type: "application/pdf")
    ]

    pdf_content = StringIO.new("fake pdf")

    @mock_api.expect(:list_folder_tree, { folders: drive_folders, status: :success }, [ @root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])
    @mock_api.expect(:export_as_html, { status: :success, content: "<p>Converted</p>" }, [ "convert_me" ])
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
      assert_empty result[:errors]
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
end
