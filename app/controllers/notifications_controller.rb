class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    InAppNotification.settle_for(current_user)
    notifications = current_user.in_app_notifications.includes(:notifiable).order(created_at: :desc)
    @needs_you = notifications.needs_you
    @updates = notifications.updates.limit(30)
    @unread_count = current_user.in_app_notifications.unread.count
  end

  # Opening one marks it read and goes to what it's about
  def show
    notification = current_user.in_app_notifications.find(params[:id])
    notification.mark_as_read!
    redirect_to notification.path || notifications_path
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
    now = Time.current
    current_user.in_app_notifications.unread.update_all(read: true, read_at: now)
    # Reading is all an update asks; what needs you stays until it's dealt with
    current_user.in_app_notifications.updates.unresolved.update_all(resolved_at: now)

    respond_to do |format|
      format.html { redirect_to notifications_path, notice: "All notifications marked as read." }
      format.turbo_stream
      format.json { head :ok }
    end
  end
end
