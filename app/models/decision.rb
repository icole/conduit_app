class Decision < ApplicationRecord
  include Discardable

  acts_as_tenant :community

  belongs_to :document, optional: true

  validates :title, presence: true

  # Scope to get decisions ordered by most recent first
  scope :recent, -> { order(decision_date: :desc, created_at: :desc) }
  scope :by_date, ->(date) { where(decision_date: date) }

  # Helper to get a formatted decision date
  def formatted_date
    decision_date&.strftime("%B %d, %Y") || "No date set"
  end
end
