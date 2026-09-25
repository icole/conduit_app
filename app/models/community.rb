class Community < ApplicationRecord
  # Status and feature-flag changes are audited (see Admin::CommunitiesController)
  has_paper_trail
  # has_many associations are optional with acts_as_tenant
  # but useful for admin/reporting queries
  has_many :users, dependent: :destroy
  has_many :households, dependent: :destroy
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

  # Per-community feature flags for the metered third-party features. Off by
  # default so a self-created community costs nothing until it is approved
  # and switched on; existing communities were backfilled to on.
  FEATURE_FLAGS = %w[chat_enabled collaborative_docs_enabled].freeze

  FEATURE_FLAGS.each do |flag|
    define_method("#{flag}?") { settings&.dig(flag) == true }
    define_method("#{flag}=") { |value| self.settings = (settings || {}).merge(flag => ActiveModel::Type::Boolean.new.cast(value)) }
  end

  # Whether Stream chat may be used: the community must be active and have chat on.
  def chat_available?
    chat_unavailable_reason.nil?
  end

  # nil when chat is available, otherwise the machine-readable reason
  # ("community_not_active" or "chat_disabled") the endpoints return.
  def chat_unavailable_reason
    return "community_not_active" unless active?
    return "chat_disabled" unless chat_enabled?

    nil
  end

  # Whether Liveblocks collaborative editing may be used.
  def collaboration_available?
    docs_unavailable_reason.nil?
  end

  def docs_unavailable_reason
    return "community_not_active" unless active?
    return "docs_disabled" unless collaborative_docs_enabled?

    nil
  end

  # The chat channel (base id, before the community prefix) that coverage
  # requests are posted to when someone releases a task.
  def coverage_chat_channel
    settings&.dig("coverage_chat_channel").presence || "chores"
  end

  # How often the community reviews contribution: "quarterly" or "semi_annual".
  def contribution_period_type
    settings&.dig("contribution_period_type").presence_in(ContributionPeriod::TYPES.keys) || "semi_annual"
  end

  def contribution_period_type=(value)
    self.settings = (settings || {}).merge("contribution_period_type" => value)
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
