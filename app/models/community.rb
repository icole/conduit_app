class Community < ApplicationRecord
  # has_many associations are optional with acts_as_tenant
  # but useful for admin/reporting queries
  has_many :users, dependent: :destroy
  has_many :households, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :chores, dependent: :destroy
  has_many :meals, dependent: :destroy
  has_many :meal_schedules, dependent: :destroy
  has_many :discussion_topics, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :decisions, dependent: :destroy
  has_many :invitations, dependent: :destroy

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
