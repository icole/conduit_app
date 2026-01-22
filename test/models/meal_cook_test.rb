require "test_helper"

class MealCookTest < ActiveSupport::TestCase
  setup do
    @meal_cook = meal_cooks(:head_cook_upcoming)
    @meal = meals(:upcoming_meal)
    @user = users(:one)
  end

  test "should be valid with meal and user" do
    assert @meal_cook.valid?
  end

  test "should require meal" do
    @meal_cook.meal = nil
    assert_not @meal_cook.valid?
    assert_includes @meal_cook.errors[:meal], "must exist"
  end

  test "should require user" do
    @meal_cook.user = nil
    assert_not @meal_cook.valid?
    assert_includes @meal_cook.errors[:user], "must exist"
  end

  test "should have unique user per meal" do
    duplicate = @meal.meal_cooks.build(user: @user, role: "helper")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "is already signed up to cook"
  end

  test "role defaults to helper and must be valid" do
    # Test that role defaults to helper
    cook = MealCook.new(meal: meals(:needs_cook), user: users(:six))
    assert_equal "helper", cook.role

    # Test valid roles
    cook.role = "head_cook"
    assert cook.valid?

    cook.role = "helper"
    assert cook.valid?

    # Test invalid role
    cook.role = "invalid"
    cook.valid?
    assert_includes cook.errors[:role], "is not included in the list"
  end

  test "head_cook? returns true for head cook role" do
    assert @meal_cook.head_cook?
    assert_not meal_cooks(:assistant_cook).head_cook?
  end

  test "helper? returns true for helper role" do
    assert meal_cooks(:assistant_cook).helper?
    assert_not @meal_cook.helper?
  end

  test "belongs to meal" do
    assert_equal @meal, @meal_cook.meal
  end

  test "belongs to user" do
    assert_equal @user, @meal_cook.user
  end

  test "can have multiple cooks per meal" do
    assert_equal 2, @meal.meal_cooks.count
  end

  test "can have only one head cook per meal" do
    head_cooks = @meal.meal_cooks.where(role: "head_cook")
    assert_equal 1, head_cooks.count
  end

  test "user can cook multiple meals" do
    # User one already has 2 meal_cooks (head_cook_upcoming and past_cook)
    initial_count = MealCook.where(user: @user).count
    assert_equal 2, initial_count

    other_meal = meals(:needs_cook)
    cook = MealCook.create!(meal: other_meal, user: @user, role: "head_cook")
    assert cook.valid?
    assert_equal 3, MealCook.where(user: @user).count
  end

  # Guest count tests
  test "guests_count defaults to 0" do
    cook = MealCook.new(meal: meals(:needs_cook), user: users(:six), role: "helper")
    assert_equal 0, cook.guests_count
  end

  test "guests_count must be non-negative" do
    @meal_cook.guests_count = -1
    assert_not @meal_cook.valid?
    assert_includes @meal_cook.errors[:guests_count], "must be greater than or equal to 0"
  end

  test "guests_count can be set" do
    cook = MealCook.create!(meal: meals(:needs_cook), user: users(:six), role: "helper", guests_count: 3)
    assert_equal 3, cook.guests_count
  end

  test "total_count returns 1 plus guests" do
    @meal_cook.guests_count = 0
    assert_equal 1, @meal_cook.total_count

    @meal_cook.guests_count = 2
    assert_equal 3, @meal_cook.total_count
  end

  test "guests_display returns nil when no guests" do
    @meal_cook.guests_count = 0
    assert_nil @meal_cook.guests_display
  end

  test "guests_display returns formatted string when has guests" do
    @meal_cook.guests_count = 1
    assert_equal "+1 guest", @meal_cook.guests_display

    @meal_cook.guests_count = 3
    assert_equal "+3 guests", @meal_cook.guests_display
  end

  # PaperTrail audit tests
  test "tracks version history on create" do
    meal = meals(:needs_cook)
    user = users(:six)

    cook = MealCook.create!(meal: meal, user: user, role: "helper")
    assert_equal 1, cook.versions.count
    assert_equal "create", cook.versions.last.event
  end

  test "tracks version history on destroy" do
    cook = MealCook.create!(meal: meals(:needs_cook), user: users(:six), role: "helper")
    cook_id = cook.id

    cook.destroy

    versions = PaperTrail::Version.where(item_type: "MealCook", item_id: cook_id)
    assert_equal 2, versions.count
    assert_equal "destroy", versions.last.event
  end

  test "can retrieve deleted cook data from version" do
    meal = meals(:needs_cook)
    user = users(:six)
    cook = MealCook.create!(meal: meal, user: user, role: "head_cook", guests_count: 2)
    cook.destroy

    last_version = PaperTrail::Version.where(item_type: "MealCook").last
    restored = last_version.reify

    assert_equal meal.id, restored.meal_id
    assert_equal user.id, restored.user_id
    assert_equal "head_cook", restored.role
    assert_equal 2, restored.guests_count
  end

  test "tracks whodunnit when set" do
    PaperTrail.request.whodunnit = "user_123"
    cook = MealCook.create!(meal: meals(:needs_cook), user: users(:six), role: "helper")

    assert_equal "user_123", cook.versions.last.whodunnit
    PaperTrail.request.whodunnit = nil
  end
end
