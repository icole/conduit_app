# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class GoogleDriveSyncServiceTest < ActiveSupport::TestCase
  setup do
    @community = communities(:crow_woods)
    ActsAsTenant.current_tenant = @community

    # Mock the Google Drive API service
    @mock_api = Minitest::Mock.new
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # Helper to create a mock Drive folder structure
  def mock_drive_folder(id:, name:, parent_id: nil)
    {
      id: id,
      name: name,
      parents: parent_id ? [ parent_id ] : nil
    }
  end

  def mock_drive_file(id:, name:, parent_id:, mime_type: "application/vnd.google-apps.document")
    {
      id: id,
      name: name,
      mime_type: mime_type,
      web_link: "https://docs.google.com/document/d/#{id}/edit",
      parents: [ parent_id ]
    }
  end

  test "creates local folders matching Drive folder structure" do
    root_folder_id = "root_drive_folder"

    # Mock folder tree response
    drive_folders = [
      mock_drive_folder(id: "folder_1", name: "Board Documents", parent_id: root_folder_id),
      mock_drive_folder(id: "folder_2", name: "Community Policies", parent_id: root_folder_id),
      mock_drive_folder(id: "folder_3", name: "2024 Archive", parent_id: "folder_1")
    ]

    @mock_api.expect(:list_folder_tree, { folders: drive_folders, status: :success }, [ root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: [], status: :success }, [ Array ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveSyncService.new(@community, root_folder_id)
      result = service.sync!

      assert result[:success]

      # Verify folders were created
      board_docs = DocumentFolder.find_by(google_drive_id: "folder_1")
      assert_not_nil board_docs
      assert_equal "Board Documents", board_docs.name
      assert_nil board_docs.parent_id

      policies = DocumentFolder.find_by(google_drive_id: "folder_2")
      assert_not_nil policies
      assert_equal "Community Policies", policies.name
      assert_nil policies.parent_id

      subfolder = DocumentFolder.find_by(google_drive_id: "folder_3")
      assert_not_nil subfolder
      assert_equal "2024 Archive", subfolder.name
      assert_equal board_docs.id, subfolder.parent_id
    end

    @mock_api.verify
  end

  test "renames local folder when Drive folder name changes" do
    root_folder_id = "root_drive_folder"

    # Create existing folder with old name
    existing_folder = DocumentFolder.create!(
      name: "Old Name",
      google_drive_id: "folder_1",
      community: @community
    )

    # Mock Drive response with new name
    drive_folders = [
      mock_drive_folder(id: "folder_1", name: "New Name", parent_id: root_folder_id)
    ]

    @mock_api.expect(:list_folder_tree, { folders: drive_folders, status: :success }, [ root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: [], status: :success }, [ Array ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveSyncService.new(@community, root_folder_id)
      result = service.sync!

      assert result[:success]

      existing_folder.reload
      assert_equal "New Name", existing_folder.name
    end

    @mock_api.verify
  end

  test "removes local folder when deleted from Drive and moves documents to root" do
    root_folder_id = "root_drive_folder"

    # Create existing folder with a document
    existing_folder = DocumentFolder.create!(
      name: "To Be Deleted",
      google_drive_id: "folder_to_delete",
      community: @community
    )
    orphaned_doc = Document.create!(
      title: "Orphaned Doc",
      google_drive_url: "https://docs.google.com/document/d/orphan123/edit",
      storage_type: :google_drive,
      document_folder: existing_folder,
      community: @community
    )

    # Mock Drive response without the deleted folder
    drive_folders = []

    @mock_api.expect(:list_folder_tree, { folders: drive_folders, status: :success }, [ root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: [], status: :success }, [ Array ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveSyncService.new(@community, root_folder_id)
      result = service.sync!

      assert result[:success]

      # Folder should be deleted
      assert_nil DocumentFolder.find_by(id: existing_folder.id)

      # Document should be moved to root (no folder)
      orphaned_doc.reload
      assert_nil orphaned_doc.document_folder_id
    end

    @mock_api.verify
  end

  test "imports files into correct folders" do
    root_folder_id = "root_drive_folder"

    drive_folders = [
      mock_drive_folder(id: "folder_1", name: "Board Minutes", parent_id: root_folder_id)
    ]

    drive_files = [
      mock_drive_file(id: "file_1", name: "January Meeting", parent_id: "folder_1"),
      mock_drive_file(id: "file_2", name: "Root Document", parent_id: root_folder_id)
    ]

    @mock_api.expect(:list_folder_tree, { folders: drive_folders, status: :success }, [ root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      service = GoogleDriveSyncService.new(@community, root_folder_id)
      result = service.sync!

      assert result[:success]

      # File in subfolder
      jan_meeting = Document.find_by(google_drive_url: "https://docs.google.com/document/d/file_1/edit")
      assert_not_nil jan_meeting
      assert_equal "January Meeting", jan_meeting.title
      folder = DocumentFolder.find_by(google_drive_id: "folder_1")
      assert_equal folder.id, jan_meeting.document_folder_id

      # File in root
      root_doc = Document.find_by(google_drive_url: "https://docs.google.com/document/d/file_2/edit")
      assert_not_nil root_doc
      assert_equal "Root Document", root_doc.title
      assert_nil root_doc.document_folder_id
    end

    @mock_api.verify
  end

  test "does not create duplicate documents on re-sync" do
    root_folder_id = "root_drive_folder"

    # Create existing document
    Document.create!(
      title: "Existing Doc",
      google_drive_url: "https://docs.google.com/document/d/existing_file/edit",
      storage_type: :google_drive,
      community: @community
    )

    drive_files = [
      mock_drive_file(id: "existing_file", name: "Existing Doc", parent_id: root_folder_id)
    ]

    @mock_api.expect(:list_folder_tree, { folders: [], status: :success }, [ root_folder_id ])
    @mock_api.expect(:list_files_in_folders, { files: drive_files, status: :success }, [ Array ])

    GoogleDriveApiService.stub(:from_service_account, @mock_api) do
      initial_count = Document.count

      service = GoogleDriveSyncService.new(@community, root_folder_id)
      result = service.sync!

      assert result[:success]
      assert_equal initial_count, Document.count
    end

    @mock_api.verify
  end
end
