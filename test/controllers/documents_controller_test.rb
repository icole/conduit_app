require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @document = documents(:one)
    sign_in_user
    # Save original method and stub it
    @original_fetch_method = DocumentsController.instance_method(:fetch_google_drive_documents)
    DocumentsController.define_method(:fetch_google_drive_documents) { }
  end

  teardown do
    # Restore original method
    DocumentsController.define_method(:fetch_google_drive_documents, @original_fetch_method)
  end

  test "should get index" do
    get documents_url
    assert_response :success
  end

  test "should get new" do
    get new_document_url
    assert_response :success
  end

  test "should create document" do
    assert_difference("Document.count") do
      post documents_url, params: { document: { description: @document.description, document_type: @document.document_type, google_drive_url: @document.google_drive_url, title: @document.title } }
    end

    assert_redirected_to document_url(Document.last)
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
