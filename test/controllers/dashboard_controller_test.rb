require "test_helper"
require "minitest/mock"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index for regular user and show posts" do
    sign_in_user
    get dashboard_index_url
    assert_response :success
    assert_equal 2, assigns(:posts).count
    assert_not_nil assigns(:post)
  end

  test "should assign drive files when drive is configured" do
    sign_in_user
    community = communities(:crow_woods)
    community.update!(settings: (community.settings || {}).merge("google_drive_folder_id" => "root123"))

    mock_service = Minitest::Mock.new
    mock_service.expect(:configured?, true)
    mock_service.expect(:list_contents, {
      folders: [],
      files: [
        { id: "f1", name: "Meeting Notes", web_link: "https://drive.google.com/f1", mime_type: "application/vnd.google-apps.document", updated_at: 1.hour.ago },
        { id: "f2", name: "Budget", web_link: "https://drive.google.com/f2", mime_type: "application/vnd.google-apps.spreadsheet", updated_at: 2.hours.ago }
      ],
      error: nil
    })

    GoogleDriveBrowseService.stub(:new, mock_service) do
      get dashboard_index_url
    end

    assert_response :success
    assert assigns(:drive_files).length == 2
    assert_select "a[href='#{documents_path}']"
    mock_service.verify
  end

  test "should handle drive not configured gracefully" do
    sign_in_user
    community = communities(:crow_woods)
    community.update!(settings: {})

    mock_service = Minitest::Mock.new
    mock_service.expect(:configured?, false)

    GoogleDriveBrowseService.stub(:new, mock_service) do
      get dashboard_index_url
    end

    assert_response :success
    assert_equal [], assigns(:drive_files)
    mock_service.verify
  end

  test "should get index for restricted user and not show posts" do
    # Sign in as a restricted user
    sign_in_user(uid: "restricted123", email: "restricted@example.com")

    # Get the signed in user and mark as restricted
    user = User.find_by(email: "restricted@example.com")
    user.update(restricted_access: true)

    get dashboard_index_url
    assert_response :success
    assert_equal 0, assigns(:posts).count
    assert_nil assigns(:post)
  end
end
