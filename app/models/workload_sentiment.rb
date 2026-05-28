class WorkloadSentiment < ApplicationRecord
  belongs_to :user
  belongs_to :role

  SENTIMENTS = %w[too_much just_right too_little].freeze

  validates :sentiment, presence: true, inclusion: { in: SENTIMENTS }
  validates :month, presence: true
  validates :user_id, uniqueness: { scope: [ :role_id, :month ] }

  scope :for_month, ->(date) { where(month: date.beginning_of_month) }
  scope :for_role, ->(role) { where(role: role) }
end
