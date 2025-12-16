require "test_helper"

class MealsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @meal = meals(:upcoming_meal)
    @needs_cook_meal = meals(:needs_cook)
    sign_in_user({ uid: @user.uid, name: @user.name, email: @user.email })
  end

  # Index action tests
  test "should get index" do
    get meals_url
    assert_response :success
    assert_select "h1", "Community Meals"
  end

  test "should get index with upcoming view" do
    get meals_url(view: "upcoming")
    assert_response :success
    assert_includes assigns(:meals), @meal
  end

  test "should get index with needs_cooks view" do
    get meals_url(view: "needs_cooks")
    assert_response :success
    assert_includes assigns(:meals), @needs_cook_meal
  end

  test "should get index with past view" do
    get meals_url(view: "past")
    assert_response :success
    assert_includes assigns(:meals), meals(:past_meal)
  end

  # Show action tests
  test "should show meal" do
    get meal_url(@meal)
    assert_response :success
    assert_select "h1", @meal.title
  end

  test "should show attendee list" do
    get meal_url(@meal)
    assert_response :success
    assert_select "h3", text: /Who's Coming/
  end

  test "should show RSVP form for upcoming meal" do
    delete logout_url
    sign_in_user({ uid: users(:four).uid, name: users(:four).name, email: users(:four).email })
    get meal_url(@meal)
    assert_response :success
    assert_select "h3", text: /Your RSVP/
  end

  test "should not show RSVP form if user is a cook" do
    meal_cooks(:head_cook_upcoming) # Ensure fixture is loaded
    get meal_url(@meal)
    assert_response :success
    # RSVP form should not be shown when user is cooking
    assert_select "form[action=?]", rsvp_meal_path(@meal), false
  end

  test "should get cook page" do
    get cook_meal_url(@needs_cook_meal)
    assert_response :success
    assert_select "h1", @needs_cook_meal.title
    assert_select "form[action=?]", volunteer_cook_meal_path(@needs_cook_meal, role: "head_cook")
  end

  test "should get show_rsvp page" do
    get rsvp_meal_url(@meal)
    assert_response :success
    assert_select "h1", @meal.title
    assert_select "form[action=?]", rsvp_meal_path(@meal)
  end

  # New action tests
  test "should get new" do
    get new_meal_url
    assert_response :success
    assert_select "h1", "Create New Meal"
  end

  # Create action tests
  test "should create meal" do
    assert_difference("Meal.count") do
      post meals_url, params: {
        meal: {
          title: "New Community Dinner",
          description: "A new meal",
          scheduled_at: 5.days.from_now.change(hour: 18, min: 0),
          location: "Common House",
          max_attendees: 25,
          rsvp_deadline: 2.days.from_now
        }
      }
    end

    assert_redirected_to meal_url(Meal.last)
    assert_equal "Meal created successfully!", flash[:notice]
  end

  test "should not create meal with invalid params" do
    assert_no_difference("Meal.count") do
      post meals_url, params: {
        meal: {
          title: "", # Invalid - blank title
          scheduled_date: 5.days.from_now.to_date,
          scheduled_time: "18:00"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # Edit action tests
  test "should get edit" do
    get edit_meal_url(@meal)
    assert_response :success
    assert_select "h1", "Edit Meal"
  end

  # Update action tests
  test "should update meal" do
    patch meal_url(@meal), params: {
      meal: {
        title: "Updated Title",
        description: "Updated description"
      }
    }
    assert_redirected_to meal_url(@meal)
    @meal.reload
    assert_equal "Updated Title", @meal.title
  end

  test "should not update meal with invalid params" do
    patch meal_url(@meal), params: {
      meal: { title: "" }
    }
    assert_response :unprocessable_entity
  end

  # Destroy action tests
  test "should destroy meal" do
    assert_difference("Meal.count", -1) do
      delete meal_url(@meal)
    end
    assert_redirected_to meals_url
    assert_equal "Meal removed.", flash[:notice]
  end

  # Calendar action tests
  test "should get calendar view" do
    get calendar_meals_url
    assert_response :success
    assert_select "h1", text: /Meal Calendar/
  end

  test "should get calendar with specific date" do
    get calendar_meals_url(date: Date.today.to_s)
    assert_response :success
  end

  # My meals action tests
  test "should get my_meals" do
    get my_meals_meals_url
    assert_response :success
    assert_select "h1", "My Meals"
  end

  # Cook volunteer action tests
  test "should volunteer as cook" do
    assert_difference("MealCook.count") do
      post volunteer_cook_meal_url(@needs_cook_meal), params: {
        meal_cook: { role: "head_cook" }
      }
    end
    assert_redirected_to meal_url(@needs_cook_meal)
    assert_equal "Thank you for volunteering to cook!", flash[:notice]
  end

  test "should not volunteer as cook twice" do
    post volunteer_cook_meal_url(@meal), params: {
      meal_cook: { role: "helper" }
    }
    assert_redirected_to meal_url(@meal)
    assert_equal "User is already signed up to cook", flash[:alert]
  end

  # Withdraw cook action tests
  test "should withdraw as cook" do
    assert_difference("MealCook.count", -1) do
      delete withdraw_cook_meal_url(@meal)
    end
    assert_redirected_to meal_url(@meal)
    assert_equal "You've withdrawn from cooking this meal.", flash[:notice]
  end

  # RSVP action tests
  test "should create RSVP" do
    meal = meals(:needs_cook)
    assert_difference("MealRsvp.count") do
      post rsvp_meal_url(meal), params: {
        meal_rsvp: {
          status: "attending",
          guests_count: 2,
          notes: "Vegetarian please"
        }
      }
    end
    assert_redirected_to meal_url(meal)
    assert_equal "Your RSVP has been recorded!", flash[:notice]
  end

  test "should update existing RSVP" do
    # User three has an RSVP for upcoming_meal
    delete logout_url
    sign_in_user({ uid: users(:three).uid, name: users(:three).name, email: users(:three).email })

    assert_no_difference("MealRsvp.count") do
      post rsvp_meal_url(@meal), params: {
        meal_rsvp: {
          status: "maybe",
          guests_count: 0
        }
      }
    end
    assert_redirected_to meal_url(@meal)
    assert_equal "Your RSVP has been recorded!", flash[:notice]
  end

  # Cancel RSVP action tests
  test "should cancel RSVP" do
    delete logout_url
    sign_in_user({ uid: users(:three).uid, name: users(:three).name, email: users(:three).email })

    assert_difference("MealRsvp.count", -1) do
      delete cancel_rsvp_meal_url(@meal)
    end
    assert_redirected_to meal_url(@meal)
    assert_equal "Your RSVP has been cancelled.", flash[:notice]
  end

  test "should not cancel non-existent RSVP" do
    delete cancel_rsvp_meal_url(@needs_cook_meal)
    assert_redirected_to meal_url(@needs_cook_meal)
    assert_equal "You didn't have an RSVP for this meal.", flash[:alert]
  end

  # Close RSVPs action tests
  test "should close RSVPs" do
    post close_rsvps_meal_url(@meal)
    assert_redirected_to meal_url(@meal)
    @meal.reload
    assert @meal.rsvps_closed?
    assert_equal "RSVPs have been closed.", flash[:notice]
  end

  # Complete meal action tests
  test "should complete meal" do
    meal = meals(:rsvps_closed)
    post complete_meal_url(meal)
    assert_redirected_to meal_url(meal)
    meal.reload
    assert meal.completed?
    assert_equal "Meal marked as completed.", flash[:notice]
  end

  # Cancel meal action tests
  test "should cancel meal" do
    post cancel_meal_url(@meal)
    assert_redirected_to meal_url(@meal)
    @meal.reload
    assert @meal.cancelled?
    assert_equal "Meal has been cancelled.", flash[:notice]
  end

  # Permissions tests
  test "should require authentication for all actions" do
    # Log out the user
    delete logout_url

    # Test each action requires authentication
    get meals_url
    assert_redirected_to login_url

    get meal_url(@meal)
    assert_redirected_to login_url

    get new_meal_url
    assert_redirected_to login_url

    post meals_url, params: { meal: { title: "Test" } }
    assert_redirected_to login_url

    get edit_meal_url(@meal)
    assert_redirected_to login_url

    patch meal_url(@meal), params: { meal: { title: "Test" } }
    assert_redirected_to login_url

    delete meal_url(@meal)
    assert_redirected_to login_url
  end

  # Mobile responsiveness tests (checking for correct classes)
  test "index page has responsive classes" do
    get meals_url
    assert_response :success
    # Check for responsive text sizes
    assert_select ".text-xl.sm\\:text-2xl"
    # Check for responsive button classes
    assert_select ".btn-sm.sm\\:btn-md"
  end

  test "show page has updated single column layout" do
    get meal_url(@meal)
    assert_response :success
    # Check for constrained width container
    assert_select ".max-w-3xl.mx-auto"
    # Ensure grid is gone
    assert_select ".grid", false
    # Check that duplication is gone (attendee list appears once in main flow, checked via having just one attendee section)
    # We can check that the mobile header or sidebar is logically present in the main flow
    assert_select ".card", minimum: 1
  end
end
