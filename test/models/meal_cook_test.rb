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
end