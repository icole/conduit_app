# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ScheduledDriveSyncJobTest < ActiveSupport::TestCase
  test "calls GoogleDriveNativeImportService#import! for communities with a Drive folder" do
    community = communities(:crow_woods)
    assert community.google_drive_folder_id.present?

    mock_service = Minitest::Mock.new
    mock_service.expect(:import!, { success: true, message: "Import complete" })

    GoogleDriveNativeImportService.stub(:new, ->(c) {
      assert_equal community.id, c.id
      mock_service
    }) do
      ScheduledDriveSyncJob.perform_now
    end

    mock_service.verify
  end

  test "skips communities without google_drive_folder_id" do
    other = communities(:other_community)
    assert_nil other.google_drive_folder_id

    # If it tried to create a service for other_community, the mock would fail
    mock_service = Minitest::Mock.new
    mock_service.expect(:import!, { success: true, message: "Import complete" })

    GoogleDriveNativeImportService.stub(:new, ->(c) {
      # Should only be called for crow_woods, never other_community
      assert_equal communities(:crow_woods).id, c.id
      mock_service
    }) do
      ScheduledDriveSyncJob.perform_now
    end

    mock_service.verify
  end
end
