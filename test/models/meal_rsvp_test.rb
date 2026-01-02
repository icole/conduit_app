require "test_helper"

class MealRsvpTest < ActiveSupport::TestCase
  setup do
    @rsvp = meal_rsvps(:attending_one)
    @meal = meals(:upcoming_meal)
    @user = users(:three)
  end

  test "should be valid with all required attributes" do
    assert @rsvp.valid?
  end

  test "should require meal" do
    @rsvp.meal = nil
    assert_not @rsvp.valid?
    assert_includes @rsvp.errors[:meal], "must exist"
  end

  test "should require user" do
    @rsvp.user = nil
    assert_not @rsvp.valid?
    assert_includes @rsvp.errors[:user], "must exist"
  end

  test "should require status" do
    @rsvp.status = nil
    assert_not @rsvp.valid?
    assert_includes @rsvp.errors[:status], "can't be blank"
  end

  test "should validate status inclusion" do
    @rsvp.status = "invalid"
    assert_not @rsvp.valid?
    assert_includes @rsvp.errors[:status], "is not included in the list"
  end

  test "should have unique user per meal" do
    duplicate = @meal.meal_rsvps.build(user: @user, status: "attending")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already RSVPed"
  end

  test "guests_count defaults to 0" do
    rsvp = MealRsvp.new(meal: @meal, user: users(:six), status: "attending")
    assert_equal 0, rsvp.guests_count
  end

  test "should validate non-negative guests_count" do
    @rsvp.guests_count = -1
    assert_not @rsvp.valid?
    assert_includes @rsvp.errors[:guests_count], "must be greater than or equal to 0"
  end

  test "belongs to meal" do
    assert_equal @meal, @rsvp.meal
  end

  test "belongs to user" do
    assert_equal @user, @rsvp.user
  end

  # Status check methods
  test "attending? returns true for attending status" do
    assert @rsvp.attending?
    assert_not meal_rsvps(:maybe).attending?
  end

  test "maybe? returns true for maybe status" do
    assert meal_rsvps(:maybe).maybe?
    assert_not @rsvp.maybe?
  end

  test "declined? returns true for declined status" do
    assert meal_rsvps(:declined).declined?
    assert_not @rsvp.declined?
  end

  test "late_plate? returns true for late_plate status" do
    assert meal_rsvps(:late_plate).late_plate?
    assert_not @rsvp.late_plate?
  end

  test "late_plate is a valid status" do
    @rsvp.status = "late_plate"
    assert @rsvp.valid?
  end

  # Display helpers
  test "guests_display returns correct text for guests" do
    assert_equal "+2 guests", @rsvp.guests_display

    @rsvp.guests_count = 1
    assert_equal "+1 guest", @rsvp.guests_display

    @rsvp.guests_count = 0
    assert_nil @rsvp.guests_display
  end

  test "total_count includes user and guests for attending" do
    assert_equal 3, @rsvp.total_count # 1 user + 2 guests

    @rsvp.guests_count = 0
    assert_equal 1, @rsvp.total_count
  end

  test "total_count returns 0 for late_plate (not seated)" do
    late_plate_rsvp = meal_rsvps(:late_plate)
    assert_equal 0, late_plate_rsvp.total_count
  end

  test "plates_count returns 1 for late_plate" do
    late_plate_rsvp = meal_rsvps(:late_plate)
    assert_equal 1, late_plate_rsvp.plates_count
  end

  test "plates_count includes user and guests for attending" do
    assert_equal 3, @rsvp.plates_count # 1 user + 2 guests
  end

  # Scope tests
  test "attending scope returns only attending RSVPs" do
    attending = MealRsvp.attending
    attending.each do |rsvp|
      assert_equal "attending", rsvp.status
    end
  end

  test "maybe scope returns only maybe RSVPs" do
    maybe = MealRsvp.maybe
    maybe.each do |rsvp|
      assert_equal "maybe", rsvp.status
    end
  end

  test "declined scope returns only declined RSVPs" do
    declined = MealRsvp.declined
    declined.each do |rsvp|
      assert_equal "declined", rsvp.status
    end
  end

  test "late_plate scope returns only late_plate RSVPs" do
    late_plates = MealRsvp.late_plate
    late_plates.each do |rsvp|
      assert_equal "late_plate", rsvp.status
    end
  end

  test "status_display returns Late Plate for late_plate status" do
    late_plate_rsvp = meal_rsvps(:late_plate)
    assert_equal "Late Plate", late_plate_rsvp.status_display
  end

  test "user can RSVP to multiple meals" do
    other_meal = meals(:needs_cook)
    rsvp = MealRsvp.create!(meal: other_meal, user: @user, status: "attending")
    assert rsvp.valid?
    assert_equal 2, MealRsvp.where(user: @user).count
  end

  test "can update RSVP status" do
    @rsvp.update!(status: "maybe")
    assert_equal "maybe", @rsvp.status
    assert @rsvp.maybe?
  end

  test "notes can be blank" do
    @rsvp.notes = nil
    assert @rsvp.valid?

    @rsvp.notes = ""
    assert @rsvp.valid?
  end
end
