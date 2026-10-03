require "test_helper"

# The Meals "Cooks" tab: thanks and community health, never a scoreboard
class MealsCooksTabTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  test "leads with the meals that still need a cook, one tap to volunteer" do
    sign_in users(:two)
    get meals_url(view: "cooks")
    assert_response :success
    assert_select "nav[aria-label='Meal views'] a[aria-current='page']", text: /Cooks/
    assert_select "#open-meals form[action='#{volunteer_cook_meal_path(meals(:needs_cook), role: "head_cook")}']"
  end

  test "shows what's recently been on the menu, and who cooked it" do
    meals(:past_meal).update!(menu: "Harvest soup and fresh bread")
    sign_in users(:two)
    get meals_url(view: "cooks")
    assert_select "#recent-menus", text: /Harvest soup and fresh bread/
    assert_select "#recent-menus", text: /#{users(:one).name.split.first}/
    assert_select "#cooks-thanks", count: 0
  end

  test "shows you your own cooking, and only yours, so you can tell if it's your turn" do
    sign_in users(:one) # cooked the past meal, and is on for the upcoming one
    get meals_url(view: "cooks")
    assert_select "#my-cooking", text: /Only you see this/
    assert_select "#my-cooking", text: /You're on for/
    assert_select "#my-cooking", text: /#{users(:two).name}/, count: 0
  end

  test "someone who hasn't cooked is invited, not compared" do
    sign_in users(:six)
    get meals_url(view: "cooks")
    assert_select "#my-cooking", text: /haven't cooked/
    assert_select "#my-cooking", text: /typical/, count: 0
  end

  test "the list of who hasn't had a turn in a while is for admins only" do
    sign_in users(:two)
    get meals_url(view: "cooks")
    assert_select "#resting-cooks", count: 0

    reset!
    sign_in users(:admin_user)
    get meals_url(view: "cooks")
    assert_select "#resting-cooks"
  end
end
