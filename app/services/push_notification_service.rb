class PushNotificationService
  class << self
    def send(user:, title:, body:, url: nil, tag: nil)
      return unless configured?

      payload = build_payload(title, body, url, tag)

      user.push_subscriptions.find_each do |subscription|
        send_to_subscription(subscription, payload)
      end
    end

    def configured?
      vapid_keys[:public_key].present? && vapid_keys[:private_key].present?
    end

    def vapid_public_key
      vapid_keys[:public_key]
    end

    private

    def vapid_keys
      @vapid_keys ||= {
        public_key: ENV["VAPID_PUBLIC_KEY"],
        private_key: ENV["VAPID_PRIVATE_KEY"],
        subject: "mailto:#{ENV.fetch('VAPID_CONTACT_EMAIL', 'admin@example.com')}"
      }.freeze
    end

    def build_payload(title, body, url, tag)
      payload = {
        title: title,
        body: body,
        icon: "/icon-192.png",
        badge: "/badge-72.png",
        data: { url: url }
      }
      payload[:tag] = tag if tag
      payload.to_json
    end

    def send_to_subscription(subscription, payload)
      return unless defined?(Webpush)

      Webpush.payload_send(
        message: payload,
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh_key,
        auth: subscription.auth_key,
        vapid: vapid_keys
      )
    rescue Webpush::ExpiredSubscription, Webpush::InvalidSubscription => e
      Rails.logger.info("Removing invalid push subscription: #{e.message}")
      subscription.destroy
    rescue StandardError => e
      Rails.logger.error("Push notification failed: #{e.message}")
    end
  end
end
