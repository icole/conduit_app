require "application_system_test_case"

class DocumentsTest < ApplicationSystemTestCase
  setup do
    @document = documents(:one)
    sign_in_user
  end

  test "visiting the index" do
    visit documents_url
    assert_selector "h1", text: "Documents"
  end

  test "should create document" do
    visit documents_url
    click_on "New document"

    fill_in "Description", with: @document.description
    fill_in "Document type", with: @document.document_type
    fill_in "Google drive url", with: @document.google_drive_url
    fill_in "Title", with: @document.title
    click_on "Create Document"

    assert_text "Document was successfully created"
    click_on "Back"
  end

  test "should update Document" do
    visit document_url(@document)
    click_on "Edit this document", match: :first

    fill_in "Description", with: @document.description
    fill_in "Document type", with: @document.document_type
    fill_in "Google drive url", with: @document.google_drive_url
    fill_in "Title", with: @document.title
    click_on "Update Document"

    assert_text "Document was successfully updated"
    click_on "Back"
  end

  test "should destroy Document" do
    visit document_url(@document)
    accept_confirm { click_on "Destroy this document", match: :first }

    assert_text "Document was successfully destroyed"
  end
end
