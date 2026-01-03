require "application_system_test_case"

class MealsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @meal = meals(:upcoming_meal)
    @meal_needing_cook = meals(:needs_cook)
  end

  test "cook can update meal menu" do
    sign_in_as_user(:one)

    visit meal_path(@meal)

    # Verify the menu section exists
    assert_selector "#meal_menu"
    assert_text "What's for Dinner"

    # Click Edit to show the form
    within "#meal_menu" do
      click_on "Edit"
    end

    # Fill in the menu
    within "#menu_edit_form" do
      fill_in "meal[menu]", with: "Tonight we're having pasta with marinara sauce, garlic bread, and salad!"
      click_on "Save Menu"
    end

    # Verify the menu was saved and is displayed
    assert_text "Tonight we're having pasta with marinara sauce, garlic bread, and salad!"

    # Verify it persisted by reloading the page
    visit meal_path(@meal)
    assert_text "Tonight we're having pasta with marinara sauce, garlic bread, and salad!"

    # Verify it's in the database
    @meal.reload
    assert_equal "Tonight we're having pasta with marinara sauce, garlic bread, and salad!", @meal.menu
  end

  test "non-cook cannot see edit button for menu" do
    # Sign in as user three who is not a cook for this meal
    sign_in_as_user(:three)

    visit meal_path(@meal)

    # Verify the menu section exists but no edit button
    assert_selector "#meal_menu"
    assert_text "What's for Dinner"
    within "#meal_menu" do
      assert_no_selector "button", text: "Edit"
    end
  end

  test "helper cook can also update meal menu" do
    # User two is a helper for upcoming_meal
    sign_in_as_user(:two)

    visit meal_path(@meal)

    # Verify the edit button is visible for helper
    within "#meal_menu" do
      click_on "Edit"
    end

    # Fill in the menu
    within "#menu_edit_form" do
      fill_in "meal[menu]", with: "Helper's menu update: Soup and sandwiches"
      click_on "Save Menu"
    end

    # Verify the menu was saved
    assert_text "Helper's menu update: Soup and sandwiches"

    @meal.reload
    assert_equal "Helper's menu update: Soup and sandwiches", @meal.menu
  end

  test "menu displays on meal card in index" do
    # Set a menu on the meal
    @meal.update!(menu: "Tacos and burritos night!")

    sign_in_as_user(:one)
    visit meals_path

    # Verify the menu shows on the card (truncated with line-clamp-2)
    assert_text "Tacos and burritos night!"
  end

  test "cook can add comment to meal" do
    sign_in_as_user(:one)

    visit meal_path(@meal)

    # Find the comments section and add a comment
    within ".card", text: "Discussion" do
      fill_in "comment[content]", with: "Looking forward to this meal!"
      click_on "Post"
    end

    # Verify the comment appears
    assert_text "Looking forward to this meal!"

    # Verify it persisted
    visit meal_path(@meal)
    assert_text "Looking forward to this meal!"
  end

  test "attending RSVP shows 'Going' badge on meals list" do
    # Create a meal and RSVP as attending
    meal = Meal.create!(
      title: "Test Meal for RSVP Badge",
      scheduled_at: 5.days.from_now,
      rsvp_deadline: 4.days.from_now,
      location: "Common House"
    )
    meal.meal_rsvps.create!(user: @user, status: "attending", guests_count: 0)

    sign_in_as_user(:one)
    visit meals_path

    within "#meal_#{meal.id}" do
      assert_selector ".badge", text: "Going"
    end
  end

  test "declined RSVP shows no attendance badge on meals list" do
    # Create a meal and RSVP as declined
    meal = Meal.create!(
      title: "Test Meal for Declined RSVP",
      scheduled_at: 5.days.from_now,
      rsvp_deadline: 4.days.from_now,
      location: "Common House"
    )
    meal.meal_rsvps.create!(user: @user, status: "declined", guests_count: 0)

    sign_in_as_user(:one)
    visit meals_path

    within "#meal_#{meal.id}" do
      # Declined users don't get a badge - no Going/Maybe/Cooking shown
      assert_no_selector ".badge", text: "Going"
      assert_no_selector ".badge", text: "Maybe"
      assert_no_selector ".badge", text: "Cooking"
    end
  end

  test "maybe RSVP shows appropriate status on meals list" do
    # Create a meal and RSVP as maybe
    meal = Meal.create!(
      title: "Test Meal for Maybe RSVP",
      scheduled_at: 5.days.from_now,
      rsvp_deadline: 4.days.from_now,
      location: "Common House"
    )
    meal.meal_rsvps.create!(user: @user, status: "maybe", guests_count: 0)

    sign_in_as_user(:one)
    visit meals_path

    within "#meal_#{meal.id}" do
      # Maybe should show a different indicator, not "Going"
      assert_no_selector ".badge", text: "Going"
      assert_selector ".badge", text: "Maybe"
    end
  end

  test "meal with helper but no head cook shows warning on meals list" do
    # Create a meal with only a helper cook (no head cook)
    meal = Meal.create!(
      title: "Test Meal Needs Head Cook",
      scheduled_at: 5.days.from_now,
      rsvp_deadline: 4.days.from_now,
      location: "Common House"
    )
    meal.meal_cooks.create!(user: @other_user, role: "helper")

    sign_in_as_user(:one)
    visit meals_path

    within "#meal_#{meal.id}" do
      # Should show warning about needing a cook (head cook)
      assert_text "Needs cook!"
    end
  end

  test "meal with head cook does not show needs head cook warning" do
    # Create a meal with a head cook
    meal = Meal.create!(
      title: "Test Meal Has Head Cook",
      scheduled_at: 5.days.from_now,
      rsvp_deadline: 4.days.from_now,
      location: "Common House"
    )
    meal.meal_cooks.create!(user: @other_user, role: "head_cook")

    sign_in_as_user(:one)
    visit meals_path

    within "#meal_#{meal.id}" do
      assert_no_text "Needs head cook!"
      assert_no_text "Needs volunteers!"
    end
  end

  test "declined RSVP appears in 'Can't Make It' section on meal show page" do
    # Create a meal and RSVP as declined
    meal = Meal.create!(
      title: "Test Meal for Declined Display",
      scheduled_at: 5.days.from_now,
      rsvp_deadline: 4.days.from_now,
      location: "Common House"
    )
    meal.meal_rsvps.create!(user: @user, status: "declined", guests_count: 0)

    sign_in_as_user(:one)
    visit meal_path(meal)

    # Should see the "Can't Make It" section with the user
    assert_text "Can't Make It"
    within ".card", text: "Who's Coming" do
      assert_text @user.name
    end
  end

  private

  def sign_in_as_user(user_fixture)
    user = users(user_fixture)

    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: user.uid,
      info: {
        name: user.name,
        email: user.email
      }
    )

    visit "/auth/google_oauth2/callback"
  end
end
