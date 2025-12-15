class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.in_app_notifications.recent
    @unread_count = current_user.in_app_notifications.unread.count
  end

  def mark_read
    @notification = current_user.in_app_notifications.find(params[:id])
    @notification.mark_as_read!

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path }
      format.turbo_stream
      format.json { head :ok }
    end
  end

  def mark_all_read
    current_user.in_app_notifications.unread.update_all(read: true, read_at: Time.current)

    respond_to do |format|
      format.html { redirect_to notifications_path, notice: "All notifications marked as read." }
      format.turbo_stream
      format.json { head :ok }
    end
  end
end
