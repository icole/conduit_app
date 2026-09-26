require "application_system_test_case"

# Pages whose inline JavaScript the behavioural suite never triggers, so the
# base class's teardown gate would never see it. Chrome only reports a blocked
# `onclick=` when something invokes it, which is why these tests click.
class ContentSecurityPolicyTest < ApplicationSystemTestCase
  test "the invitations page runs its clipboard script" do
    sign_in_as(users(:admin_user))
    visit invitations_path

    # A blocked inline <script> shows up here, at load, before any clicking.
    assert_no_csp_violations

    click_on "Copy"
    assert_no_csp_violations
  end

  test "the calendar page loads without a policy violation" do
    sign_in_as(users(:one))
    visit calendar_index_path

    assert_no_csp_violations
  end

  # users(:one) cooks this meal, so they get the cook form; admin_user doesn't,
  # so they get the RSVP form. Both carry their own guest stepper.
  test "the cook guest stepper changes the count" do
    sign_in_as(users(:one))
    visit meal_path(meals(:upcoming_meal))

    assert_stepper_increments "#cook_guests_count"
  end

  test "the RSVP guest stepper changes the count" do
    sign_in_as(users(:admin_user))
    visit meal_path(meals(:upcoming_meal))

    assert_stepper_increments "#guests_count"
  end

  private

  def assert_stepper_increments(selector)
    count = find(selector)
    before = count.value.to_i
    count.find(:xpath, "following-sibling::button").click

    assert_equal (before + 1).to_s, count.value
    assert_no_csp_violations
  end
end
