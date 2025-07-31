class ChoreCompletion < ApplicationRecord
  belongs_to :chore
  belongs_to :completed_by, class_name: "User"

  validates :completed_at, presence: true

  scope :recent, -> { order(completed_at: :desc) }
  scope :this_week, -> { where("completed_at >= ?", Date.current.beginning_of_week) }
  scope :this_month, -> { where("completed_at >= ?", Date.current.beginning_of_month) }
end
