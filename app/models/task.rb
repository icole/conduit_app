class Task < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :status, presence: true

  # Default status is 'pending'
  attribute :status, :string, default: 'pending'

  # Scopes for filtering tasks
  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }

  # Order tasks by creation date (newest first)
  default_scope { order(created_at: :desc) }
end
