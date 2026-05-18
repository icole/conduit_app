class TimeEntry < ApplicationRecord
  belongs_to :user
  belongs_to :task, optional: true
  belongs_to :role, optional: true

  ENTRY_TYPES = %w[task reconciliation].freeze

  validates :hours, presence: true, numericality: { greater_than: 0 }
  validates :logged_on, presence: true
  validates :entry_type, presence: true, inclusion: { in: ENTRY_TYPES }

  scope :task_entries, -> { where(entry_type: "task") }
  scope :reconciliation_entries, -> { where(entry_type: "reconciliation") }
  scope :for_month, ->(year, month) {
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    where(logged_on: start_date..end_date)
  }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_role, ->(role) { where(role: role) }
  scope :recent, -> { order(logged_on: :desc) }
end
