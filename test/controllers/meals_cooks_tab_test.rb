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

  test "thanks this year's cooks by name, with no counts beside them" do
    sign_in users(:two)
    get meals_url(view: "cooks")
    assert_select "#cooks-thanks li", minimum: 1
    css_select("#cooks-thanks li").each { |li| assert_no_match(/\d/, li.text, "no numbers next to anyone's name") }
  end

  test "shows you your own cooking, and only yours" do
    sign_in users(:one) # cooked the past meal
    get meals_url(view: "cooks")
    assert_select "#my-cooking", text: /You've cooked 1 meal/
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
