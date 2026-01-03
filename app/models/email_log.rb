# frozen_string_literal: true

class EmailLog < ApplicationRecord
  acts_as_tenant :community

  STATUSES = %w[pending delivered failed].freeze

  validates :to, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :delivered, -> { where(status: "delivered") }
  scope :failed, -> { where(status: "failed") }
  scope :pending, -> { where(status: "pending") }

  def delivered?
    status == "delivered"
  end

  def failed?
    status == "failed"
  end

  def pending?
    status == "pending"
  end
end
