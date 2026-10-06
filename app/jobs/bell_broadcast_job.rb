# Sends members' pages in the apps their bell's current count (CON-72), so it
# changes as things happen, not only when a page loads
class BellBroadcastJob < ApplicationJob
  queue_as :default

  def self.for_users(user_ids)
    user_ids = user_ids.compact.uniq
    perform_later(user_ids) if user_ids.any?
  end

  # Everyone with something outstanding about this meal or task, and anyone else named
  def self.about(record, *user_ids)
    for_users(InAppNotification.unresolved.where(notifiable: record).distinct.pluck(:user_id) + user_ids)
  end

  def perform(user_ids)
    ActsAsTenant.without_tenant { User.where(id: user_ids).to_a }.each do |user|
      ActsAsTenant.with_tenant(user.community) do
        InAppNotification.settle_for(user)
        Turbo::StreamsChannel.broadcast_replace_to(user, :bell, target: "native-bell",
          partial: "notifications/native_bell", locals: { count: user.in_app_notifications.needs_you.count })
      end
    end
  end
end
