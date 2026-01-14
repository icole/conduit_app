require "test_helper"

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

  test "should get new" do
    get new_document_url
    assert_response :success
  end

  test "should create document" do
    assert_difference("Document.count") do
      post documents_url, params: { document: { description: @document.description, document_type: @document.document_type, google_drive_url: @document.google_drive_url, title: @document.title, storage_type: @document.storage_type } }
    end

    assert_redirected_to document_url(Document.last)
  end

  test "should create native document and redirect to edit" do
    assert_difference("Document.count") do
      post documents_url, params: { document: { title: "New Native Doc", description: "Test", storage_type: "native" } }
    end

    assert_redirected_to edit_document_url(Document.last)
  end

  test "should create document in folder" do
    folder = DocumentFolder.create!(name: "Test Folder", community: communities(:crow_woods))

    assert_difference("Document.count") do
      post documents_url, params: { document: { title: "Folder Doc", description: "In folder", document_folder_id: folder.id } }
    end

    document = Document.last
    assert_equal folder, document.document_folder
  end

  test "should show document" do
    get document_url(@document)
    assert_response :success
  end

  test "should get edit" do
    get edit_document_url(@document)
    assert_response :success
  end

  test "should update document" do
    patch document_url(@document), params: { document: { description: @document.description, document_type: @document.document_type, google_drive_url: @document.google_drive_url, title: @document.title } }
    assert_redirected_to document_url(@document)
  end

  test "should destroy document" do
    assert_difference("Document.count", -1) do
      delete document_url(@document)
    end

    assert_redirected_to documents_url
  end
end
