# frozen_string_literal: true

class Household < ApplicationRecord
  acts_as_tenant :community

  has_many :users, dependent: :nullify
  has_many :household_dues_payments, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :community_id }

  def dues_paid_for?(year:, month:)
    household_dues_payments.exists?(year: year, month: month, paid: true)
  end

  def dues_payment_for(year:, month:)
    household_dues_payments.find_or_initialize_by(year: year, month: month)
  end

  def member_names
    users.pluck(:name).join(", ")
  end
end
