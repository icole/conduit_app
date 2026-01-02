require "test_helper"

class MealTest < ActiveSupport::TestCase
  setup do
    @meal = meals(:upcoming_meal)
    @past_meal = meals(:past_meal)
    @cancelled_meal = meals(:cancelled_meal)
  end

  # Validation tests
  test "should be valid with all required attributes" do
    assert @meal.valid?
  end

  test "should auto-generate title when blank" do
    @meal.title = nil
    @meal.valid?
    assert @meal.title.present?, "Title should be auto-generated"
    assert_match @meal.scheduled_at.strftime("%A"), @meal.title
  end

  test "should require scheduled_at" do
    @meal.scheduled_at = nil
    assert_not @meal.valid?
  end

  test "should require rsvp_deadline" do
    @meal.rsvp_deadline = nil
    assert_not @meal.valid?
  end

  test "should require status" do
    @meal.status = nil
    assert_not @meal.valid?
  end

  test "should validate status inclusion" do
    @meal.status = "invalid_status"
    assert_not @meal.valid?
    assert_includes @meal.errors[:status], "is not included in the list"
  end

  test "should validate rsvp_deadline is before meal" do
    @meal.rsvp_deadline = @meal.scheduled_at + 1.hour
    assert_not @meal.valid?
    assert_includes @meal.errors[:rsvp_deadline], "must be before the meal time"
  end

  # Association tests
  test "should have many meal_cooks" do
    assert_respond_to @meal, :meal_cooks
  end

  test "should have many cooks through meal_cooks" do
    assert_respond_to @meal, :cooks
  end

  test "should have many meal_rsvps" do
    assert_respond_to @meal, :meal_rsvps
  end

  test "should have many attendees through meal_rsvps" do
    assert_respond_to @meal, :attendees
  end

  # Scope tests
  test "upcoming scope returns future meals" do
    upcoming = Meal.upcoming
    assert_includes upcoming, @meal
    assert_not_includes upcoming, @past_meal
  end

  test "upcoming scope includes meals with rsvps_closed status" do
    upcoming = Meal.upcoming
    assert_includes upcoming, meals(:rsvps_closed)
  end

  test "upcoming scope excludes cancelled meals" do
    upcoming = Meal.upcoming
    assert_not_includes upcoming, @cancelled_meal
  end

  test "needs_cooks scope returns meals without cooks" do
    needs_cooks = Meal.needs_cooks
    assert_includes needs_cooks, meals(:needs_cook)
  end

  test "past scope returns past meals" do
    past = Meal.past
    assert_includes past, @past_meal
    assert_not_includes past, @meal
  end

  # Status check methods
  test "upcoming? returns true for upcoming meals" do
    assert @meal.upcoming?
    assert_not @past_meal.upcoming?
  end

  test "completed? returns true for completed meals" do
    assert @past_meal.completed?
    assert_not @meal.completed?
  end

  test "cancelled? returns true for cancelled meals" do
    assert @cancelled_meal.cancelled?
    assert_not @meal.cancelled?
  end

  test "rsvps_open? returns true when RSVPs are open" do
    assert @meal.rsvps_open?
    assert_not meals(:rsvps_closed).rsvps_open?
  end

  test "rsvps_closed? returns true when RSVPs are closed" do
    assert meals(:rsvps_closed).rsvps_closed?
    assert_not @meal.rsvps_closed?
  end

  # Attendance calculations
  test "total_attendees counts cooks, RSVPs and guests" do
    # upcoming_meal has:
    # - 2 cooks (head_cook_upcoming and assistant_cook)
    # - 2 attending RSVPs (attending_one with 2 guests, attending_two with 0 guests)
    # Total: 2 cooks + 2 people + 2 guests = 6
    assert_equal 6, @meal.total_attendees
  end

  test "meal_rsvps.attending returns only attending RSVPs" do
    attending = @meal.meal_rsvps.attending
    assert_equal 2, attending.count
    attending.each do |rsvp|
      assert_equal "attending", rsvp.status
    end
  end

  test "meal_rsvps.maybe returns only maybe RSVPs" do
    maybe = @meal.meal_rsvps.maybe
    assert_equal 1, maybe.count
    maybe.each do |rsvp|
      assert_equal "maybe", rsvp.status
    end
  end

  # State transition methods
  test "cancel! changes status to cancelled" do
    @meal.cancel!
    assert_equal "cancelled", @meal.status
    assert @meal.cancelled?
  end

  test "close_rsvps! changes status to rsvps_closed" do
    @meal.close_rsvps!
    assert_equal "rsvps_closed", @meal.status
    assert @meal.rsvps_closed?
  end

  test "complete! changes status to completed" do
    @meal.complete!
    assert_equal "completed", @meal.status
    assert @meal.completed?
  end

  test "reopen_rsvps! changes status to upcoming" do
    meals(:rsvps_closed).reopen_rsvps!
    assert_equal "upcoming", meals(:rsvps_closed).reload.status
  end

  # Display helpers
  test "full_display returns formatted date and time" do
    display = @meal.full_display
    assert_match @meal.scheduled_at.strftime("%B"), display
    assert display.present?
  end

  test "time_display returns formatted time" do
    expected = @meal.scheduled_at.strftime("%l:%M %p").strip
    assert_equal expected, @meal.time_display
  end

  test "date_display returns formatted date" do
    date = @meal.date_display
    assert date.is_a?(String)
    assert date.present?
  end

  # Cook-related methods
  test "cook_slots_available? returns true when slots available" do
    assert meals(:needs_cook).cook_slots_available?
  end

  test "user_is_cook? returns true when user is a cook" do
    user = users(:one)
    assert @meal.user_is_cook?(user)
    assert_not meals(:needs_cook).user_is_cook?(user)
  end

  test "head_cook returns the head cook user" do
    head_cook = @meal.head_cook
    assert_equal users(:one), head_cook
  end

  test "needs_head_cook? returns true when no head cook" do
    assert meals(:needs_cook).needs_head_cook?
    assert_not @meal.needs_head_cook?
  end

  # RSVP-related methods
  test "user_rsvped? returns true when user has RSVP" do
    user = users(:three)
    assert @meal.user_rsvped?(user)
  end

  test "rsvp_for returns user's RSVP" do
    user = users(:three)
    rsvp = @meal.rsvp_for(user)
    assert_equal meal_rsvps(:attending_one), rsvp
  end

  test "user_attending? returns true when user is attending" do
    user = users(:three)
    assert @meal.user_attending?(user)

    user_maybe = users(:five)
    assert_not @meal.user_attending?(user_maybe)
  end

  # Dependent destroy
  test "destroying meal destroys associated records" do
    meal = meals(:needs_cook)
    meal.meal_rsvps.create!(user: users(:one), status: "attending")
    meal.meal_cooks.create!(user: users(:two))

    assert_difference [ "MealRsvp.count", "MealCook.count" ], -1 do
      meal.destroy
    end
  end
end
