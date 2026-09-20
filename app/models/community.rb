class Community < ApplicationRecord
  # has_many associations are optional with acts_as_tenant
  # but useful for admin/reporting queries
  has_many :users, dependent: :destroy
  has_many :households, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :meals, dependent: :destroy
  has_many :meal_schedules, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :decisions, dependent: :destroy
  has_many :invitations, dependent: :destroy

  # Lifecycle: self-created communities start pending; approval unlocks the
  # metered features (chat, collaborative docs); suspension locks members out.
  enum :status, { pending: "pending", active: "active", suspended: "suspended" }, default: "pending"

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  validates :domain, presence: true, uniqueness: true

  # Settings accessors for Google integration
  def google_calendar_id
    settings&.dig("google_calendar_id")
  end

  def google_drive_folder_id
    settings&.dig("google_drive_folder_id")
  end

  def smtp_from_name
    settings&.dig("smtp_from_name") || "#{name} Conduit"
  end

  def smtp_from_address
    "#{smtp_from_name} <#{settings&.dig('smtp_username') || ENV['SMTP_USERNAME']}>"
  end

  def approve!
    update!(status: "active")
    CommunityMailer.approved(self).deliver_later
  end

  # Members can no longer use the app; existing mobile sessions end immediately.
  def suspend!
    transaction do
      update!(status: "suspended")
      ActsAsTenant.with_tenant(self) { User.find_each(&:revoke_mobile_tokens!) }
    end
  end

  # Whether Stream chat may be used. CON-59 adds the per-community flag here.
  def chat_available?
    active?
  end

  # Whether Liveblocks collaborative editing may be used.
  def collaboration_available?
    active?
  end

  def dues_tracking_enabled?
    monthly_dues_amount.present? && monthly_dues_amount > 0
  end

  # Meal scheduling settings
  def meal_buffer_weeks
    settings&.dig("meal_buffer_weeks")&.to_i || 6
  end

  def meal_buffer_weeks=(value)
    self.settings = (settings || {}).merge("meal_buffer_weeks" => value.to_i)
  end
end
