require "test_helper"

class CalendarShareTest < ActiveSupport::TestCase
  test "should validate presence of calendar_id" do
    share = CalendarShare.new(user: users(:one))
    assert_not share.valid?
    assert_includes share.errors[:calendar_id], "can't be blank"
  end

  test "should validate uniqueness of user_id scoped to calendar_id" do
    # Create first share
    calendar_id = "test_calendar_id"
    CalendarShare.create!(user: users(:one), calendar_id: calendar_id)

    # Try to create duplicate share
    duplicate = CalendarShare.new(user: users(:one), calendar_id: calendar_id)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "already has access to this calendar"

    # Different user should be valid
    different_user = CalendarShare.new(user: users(:two), calendar_id: calendar_id)
    assert different_user.valid?
  end

  test "calendar_shared_with_user? should return true when calendar is shared" do
    calendar_id = "test_calendar_id"
    user = users(:one)

    # Initially not shared
    assert_not CalendarShare.calendar_shared_with_user?(calendar_id, user)

    # Create share
    CalendarShare.create!(user: user, calendar_id: calendar_id)

    # Now should be shared
    assert CalendarShare.calendar_shared_with_user?(calendar_id, user)
  end
end
