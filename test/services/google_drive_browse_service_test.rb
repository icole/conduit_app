require "test_helper"
require "minitest/mock"

class GoogleDriveBrowseServiceTest < ActiveSupport::TestCase
  setup do
    @community = communities(:crow_woods)
  end

  test "configured? returns false when community has no google_drive_folder_id" do
    @community.settings = {}
    service = GoogleDriveBrowseService.new(@community)
    assert_not service.configured?
  end

  test "configured? returns true when community has google_drive_folder_id" do
    @community.settings = { "google_drive_folder_id" => "abc123" }
    service = GoogleDriveBrowseService.new(@community)
    assert service.configured?
  end

  test "list_contents returns folders and files for given parent" do
    @community.settings = { "google_drive_folder_id" => "root_folder" }
    service = GoogleDriveBrowseService.new(@community)

    mock_api = Minitest::Mock.new
    mock_api.expect(:list_folders, {
      folders: [
        { id: "folder1", name: "Meeting Notes", web_link: "https://drive.google.com/folder1" }
      ],
      status: :success
    }, parent_folder_id: "root_folder")

    mock_api.expect(:list_files_in_folders, {
      files: [
        { id: "file1", name: "Budget.xlsx", web_link: "https://drive.google.com/file1", mime_type: "application/vnd.google-apps.spreadsheet" }
      ],
      status: :success
    }, [ [ "root_folder" ] ])

    GoogleDriveApiService.stub(:from_service_account, mock_api) do
      result = service.list_contents
      assert_nil result[:error]
      assert_equal 1, result[:folders].length
      assert_equal "Meeting Notes", result[:folders].first[:name]
      assert_equal 1, result[:files].length
      assert_equal "Budget.xlsx", result[:files].first[:name]
    end

    mock_api.verify
  end

  test "list_contents uses specified parent_id" do
    @community.settings = { "google_drive_folder_id" => "root_folder" }
    service = GoogleDriveBrowseService.new(@community)

    mock_api = Minitest::Mock.new
    mock_api.expect(:list_folders, { folders: [], status: :success }, parent_folder_id: "subfolder_id")
    mock_api.expect(:list_files_in_folders, { files: [], status: :success }, [ [ "subfolder_id" ] ])

    GoogleDriveApiService.stub(:from_service_account, mock_api) do
      result = service.list_contents("subfolder_id")
      assert_nil result[:error]
      assert_equal [], result[:folders]
      assert_equal [], result[:files]
    end

    mock_api.verify
  end

  test "list_contents returns error on API failure" do
    @community.settings = { "google_drive_folder_id" => "root_folder" }
    service = GoogleDriveBrowseService.new(@community)

    GoogleDriveApiService.stub(:from_service_account, -> { raise StandardError, "API unavailable" }) do
      result = service.list_contents
      assert_equal "API unavailable", result[:error]
      assert_equal [], result[:folders]
      assert_equal [], result[:files]
    end
  end

  test "recent_files delegates to list_recent_files on the API" do
    @community.settings = { "google_drive_folder_id" => "root_folder" }
    service = GoogleDriveBrowseService.new(@community)

    mock_api = Minitest::Mock.new
    mock_api.expect(:list_recent_files, {
      files: [
        { id: "f1", name: "Recent Doc", web_link: "https://drive.google.com/f1", updated_at: 1.hour.ago }
      ],
      status: :success
    }, [ "root_folder" ], max_results: 5)

    GoogleDriveApiService.stub(:from_service_account, mock_api) do
      result = service.recent_files
      assert_nil result[:error]
      assert_equal 1, result[:files].length
      assert_equal "Recent Doc", result[:files].first[:name]
    end

    mock_api.verify
  end

  test "recent_files returns error on API failure" do
    @community.settings = { "google_drive_folder_id" => "root_folder" }
    service = GoogleDriveBrowseService.new(@community)

    GoogleDriveApiService.stub(:from_service_account, -> { raise StandardError, "API down" }) do
      result = service.recent_files
      assert_equal "API down", result[:error]
      assert_equal [], result[:files]
    end
  end

  test "list_contents handles folder listing error gracefully" do
    @community.settings = { "google_drive_folder_id" => "root_folder" }
    service = GoogleDriveBrowseService.new(@community)

    mock_api = Minitest::Mock.new
    mock_api.expect(:list_folders, { folders: [], status: :client_error, error: "Not found" }, parent_folder_id: "root_folder")
    mock_api.expect(:list_files_in_folders, { files: [ { id: "f1", name: "File" } ], status: :success }, [ [ "root_folder" ] ])

    GoogleDriveApiService.stub(:from_service_account, mock_api) do
      result = service.list_contents
      assert_nil result[:error]
      assert_equal [], result[:folders]
      assert_equal 1, result[:files].length
    end

    mock_api.verify
  end
end
