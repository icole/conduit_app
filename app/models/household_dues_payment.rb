# frozen_string_literal: true

class HouseholdDuesPayment < ApplicationRecord
  belongs_to :household

  validates :year, presence: true, numericality: { only_integer: true, greater_than: 2000 }
  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :household_id, uniqueness: { scope: [ :year, :month ], message: "already has a payment record for this month" }

  scope :for_year, ->(year) { where(year: year) }
  scope :for_month, ->(year, month) { where(year: year, month: month) }
  scope :paid, -> { where(paid: true) }
  scope :unpaid, -> { where(paid: false) }
end
