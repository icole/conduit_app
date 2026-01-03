# frozen_string_literal: true

require "test_helper"

class HouseholdTest < ActiveSupport::TestCase
  setup do
    @community = communities(:crow_woods)
    ActsAsTenant.current_tenant = @community
  end

  test "requires name" do
    household = Household.new(name: nil)
    assert_not household.valid?
    assert_includes household.errors[:name], "can't be blank"
  end

  test "name must be unique within community" do
    existing = households(:smith_household)
    duplicate = Household.new(name: existing.name)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "same name allowed in different communities" do
    ActsAsTenant.current_tenant = communities(:other_community)
    household = Household.new(name: "The Smith Family")
    assert household.valid?
  end

  test "dues_paid_for? returns true when paid" do
    household = households(:smith_household)
    assert household.dues_paid_for?(year: 2026, month: 1)
  end

  test "dues_paid_for? returns false when unpaid" do
    household = households(:smith_household)
    assert_not household.dues_paid_for?(year: 2026, month: 2)
  end

  test "dues_paid_for? returns false when no record exists" do
    household = households(:empty_household)
    assert_not household.dues_paid_for?(year: 2026, month: 1)
  end

  test "dues_payment_for creates new record if not exists" do
    household = households(:empty_household)
    payment = household.dues_payment_for(year: 2026, month: 3)
    assert payment.new_record?
    assert_equal 2026, payment.year
    assert_equal 3, payment.month
  end

  test "dues_payment_for returns existing record" do
    household = households(:smith_household)
    existing = household_dues_payments(:smith_january_paid)
    payment = household.dues_payment_for(year: 2026, month: 1)
    assert_equal existing, payment
  end

  test "destroying household nullifies user associations" do
    household = households(:smith_household)
    user = users(:one)
    user.update!(household: household)

    household.destroy

    user.reload
    assert_nil user.household_id
  end
end
