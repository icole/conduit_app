# frozen_string_literal: true

require "test_helper"

class HouseholdDuesPaymentTest < ActiveSupport::TestCase
  setup do
    @community = communities(:crow_woods)
    ActsAsTenant.current_tenant = @community
  end

  test "validates presence of year" do
    payment = HouseholdDuesPayment.new(household: households(:smith_household), month: 1)
    assert_not payment.valid?
    assert_includes payment.errors[:year], "can't be blank"
  end

  test "validates presence of month" do
    payment = HouseholdDuesPayment.new(household: households(:smith_household), year: 2026)
    assert_not payment.valid?
    assert_includes payment.errors[:month], "can't be blank"
  end

  test "validates month is between 1 and 12" do
    household = households(:empty_household)

    payment = HouseholdDuesPayment.new(household: household, year: 2026, month: 0)
    assert_not payment.valid?
    assert_includes payment.errors[:month], "is not included in the list"

    payment.month = 13
    assert_not payment.valid?
    assert_includes payment.errors[:month], "is not included in the list"

    payment.month = 6
    assert payment.valid?
  end

  test "validates uniqueness of household/year/month" do
    existing = household_dues_payments(:smith_january_paid)
    duplicate = HouseholdDuesPayment.new(
      household: existing.household,
      year: existing.year,
      month: existing.month
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:household_id], "already has a payment record for this month"
  end

  test "for_year scope filters by year" do
    payments = HouseholdDuesPayment.for_year(2026)
    assert payments.all? { |p| p.year == 2026 }
  end

  test "paid scope filters paid payments" do
    payments = HouseholdDuesPayment.paid
    assert payments.all?(&:paid)
  end

  test "unpaid scope filters unpaid payments" do
    payments = HouseholdDuesPayment.unpaid
    assert payments.none?(&:paid)
  end

  test "defaults paid to false" do
    payment = HouseholdDuesPayment.new(
      household: households(:empty_household),
      year: 2026,
      month: 5
    )
    assert_equal false, payment.paid
  end
end
