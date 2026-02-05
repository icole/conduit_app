require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = communities(:crow_woods)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "google_drive_file_id extracts id from docs url" do
    document = Document.new(
      title: "Test",
      google_drive_url: "https://docs.google.com/document/d/1abc123XYZ_-test/edit",
      storage_type: :google_drive
    )
    assert_equal "1abc123XYZ_-test", document.google_drive_file_id
  end

  test "google_drive_file_id extracts id from drive file url" do
    document = Document.new(
      title: "Test",
      google_drive_url: "https://drive.google.com/file/d/1abc123XYZ_-test/view",
      storage_type: :google_drive
    )
    assert_equal "1abc123XYZ_-test", document.google_drive_file_id
  end

  test "google_drive_file_id extracts id from spreadsheet url" do
    document = Document.new(
      title: "Test",
      google_drive_url: "https://docs.google.com/spreadsheets/d/1abc123XYZ_-test/edit#gid=0",
      storage_type: :google_drive
    )
    assert_equal "1abc123XYZ_-test", document.google_drive_file_id
  end

  test "google_drive_file_id returns nil for blank url" do
    document = Document.new(title: "Test", storage_type: :native)
    assert_nil document.google_drive_file_id
  end

  test "google_drive_file_id returns nil for invalid url" do
    document = Document.new(
      title: "Test",
      google_drive_url: "https://example.com/something",
      storage_type: :google_drive
    )
    assert_nil document.google_drive_file_id
  end

  test "uploaded? returns true for uploaded storage type" do
    document = Document.new(title: "Test", storage_type: :uploaded)
    assert document.uploaded?
  end

  test "uploaded? returns false for native storage type" do
    document = Document.new(title: "Test", storage_type: :native)
    assert_not document.uploaded?
  end

  test "uploaded document requires file attachment" do
    document = Document.new(title: "Test", storage_type: :uploaded)
    assert_not document.valid?
    assert_includes document.errors[:file], "must be attached for uploaded documents"
  end

  test "uploaded document is valid with file attached" do
    document = Document.new(title: "Test", storage_type: :uploaded)
    document.file.attach(
      io: StringIO.new("test content"),
      filename: "test.txt",
      content_type: "text/plain"
    )
    assert document.valid?
  end
end
