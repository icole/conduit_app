require "test_helper"
require "minitest/mock"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @document = documents(:one)
    sign_in_user
  end

  test "should get index" do
    get documents_url
    assert_response :success
  end

  test "should get index with folder_id" do
    folder = DocumentFolder.create!(name: "Test Folder", community: communities(:crow_woods))
    get documents_url(folder_id: folder.id)
    assert_response :success
  end

  test "should create untitled document and redirect to edit" do
    assert_difference("Document.count") do
      post documents_url
    end

    document = Document.last
    assert_equal "Untitled Document", document.title
    assert document.native?, "Document should be created as native"
    assert_redirected_to edit_document_url(document)
  end

  test "should create document in folder" do
    folder = DocumentFolder.create!(name: "Test Folder For Create", community: communities(:crow_woods))

    assert_difference("Document.count") do
      post documents_url, params: { document: { document_folder_id: folder.id } }
    end

    document = Document.last
    assert_equal folder, document.document_folder
    assert_equal "Untitled Document", document.title
  end

  test "should show document redirects google drive doc to view_content" do
    get document_url(@document)
    assert_redirected_to view_content_document_url(@document)
  end

  test "should get edit for native document" do
    native_doc = documents(:native_doc)
    get edit_document_url(native_doc)
    assert_response :success
  end

  test "edit redirects google drive document to view_content" do
    get edit_document_url(@document)
    assert_redirected_to view_content_document_url(@document)
  end

  test "should update document" do
    patch document_url(@document), params: { document: { description: @document.description, document_type: @document.document_type, google_drive_url: @document.google_drive_url, title: @document.title } }
    assert_redirected_to document_url(@document)
  end

  test "should destroy native document" do
    native_doc = documents(:native_doc)

    assert_difference("Document.count", -1) do
      delete document_url(native_doc)
    end

    assert_redirected_to documents_url
  end

  test "should not destroy google drive document" do
    assert_no_difference("Document.count") do
      delete document_url(@document)
    end

    assert_redirected_to documents_url
    assert_equal "Cannot delete documents synced from Google Drive.", flash[:alert]
  end

  test "show redirects native document to edit" do
    native_doc = documents(:native_doc)
    get document_url(native_doc)
    assert_redirected_to edit_document_url(native_doc)
  end

  test "view_content redirects native document to edit" do
    native_doc = documents(:native_doc)
    get view_content_document_url(native_doc)
    assert_redirected_to edit_document_url(native_doc)
  end

  test "view_content renders for google drive document" do
    # Mock the Google Drive API service
    mock_api = Minitest::Mock.new
    mock_api.expect(:export_as_html, {
      status: :success,
      content: "<p>Test document content</p>",
      name: "Test Document",
      mime_type: "application/vnd.google-apps.document"
    }, [ "1FakeDocumentId123456789abcdefghijklmnopqrstuvwxyz" ])

    GoogleDriveApiService.stub(:from_service_account, mock_api) do
      get view_content_document_url(@document)
      assert_response :success
      assert_select "div.google-drive-content"
    end

    mock_api.verify
  end

  test "view_content shows error when api fails" do
    mock_api = Minitest::Mock.new
    mock_api.expect(:export_as_html, {
      status: :client_error,
      error: "File not found"
    }, [ "1FakeDocumentId123456789abcdefghijklmnopqrstuvwxyz" ])

    GoogleDriveApiService.stub(:from_service_account, mock_api) do
      get view_content_document_url(@document)
      assert_response :success
      assert_select "div.alert-warning"
    end

    mock_api.verify
  end
end
