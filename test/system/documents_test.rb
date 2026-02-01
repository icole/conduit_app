require "application_system_test_case"

class DocumentsTest < ApplicationSystemTestCase
  setup do
    @document = documents(:one)
    @native_document = documents(:native_doc)

    sign_in_user
  end

  test "visiting the index" do
    visit documents_url
    assert_selector "h1", text: "Documents"
  end

  test "should create document" do
    visit documents_url

    count_before = Document.count
    click_on "New Document"

    # Should redirect to edit page for the new native document
    assert_text "Untitled Document", wait: 5
    assert_equal count_before + 1, Document.count
  end

  test "should show native document edit page" do
    visit edit_document_url(@native_document)

    assert_selector "[data-title]", text: @native_document.title, wait: 5
    assert_selector "button[title='Rename']"
  end

  test "should destroy native document from index" do
    visit documents_url

    accept_confirm do
      find("form[action='#{document_path(@native_document)}'] button.btn-error").click
    end

    assert_current_path documents_path, wait: 5
    assert_text "Document was successfully deleted"
  end
end
