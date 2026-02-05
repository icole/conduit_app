class DriveSyncChannel < ApplicationCable::Channel
  def subscribed
    stream_from "drive_sync_#{current_user.id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def refresh_files
    # Trigger a background job to refresh files
    ScheduledDriveSyncJob.perform_later
  end
end
