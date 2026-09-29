# A phone we can send push notifications to, registered by the app at
# sign-in (Api::V1::PushDevicesController) and owned by the signed-in user.
# An invalid or expired token is destroyed when APNs/FCM rejects it.
class ApplicationPushDevice < ActionPushNative::Device
  validates :token, presence: true, uniqueness: { scope: :platform }

  # Sending needs that platform's credentials on the server (config/push.yml);
  # until they're set, pushes to it are skipped rather than failing.
  def push(notification)
    super if self.class.platform_configured?(platform)
  end

  def self.platform_configured?(platform)
    case platform.to_s
    when "apple" then ENV["APNS_KEY"].present? && ENV["APNS_KEY_ID"].present? && ENV["APNS_TEAM_ID"].present?
    when "google" then ENV["FCM_SERVICE_ACCOUNT"].present? && ENV["FCM_PROJECT_ID"].present?
    else false
    end
  end
end
