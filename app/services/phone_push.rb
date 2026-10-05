# A push to the member's registered phones (the iOS and Android apps).
# Tapping it opens +path+ in the app. Nothing is sent to someone without one.
class PhonePush
  def self.deliver(user, title:, body:, path:, thread:)
    devices = user.push_devices.to_a
    return if devices.empty?

    ApplicationPushNotification.with_data(path: path)
      .new(title: title, body: body, thread_id: thread)
      .deliver_later_to(devices)
  end
end
