require "application_system_test_case"

# Google profile photo links expire; a photo that won't load shows initials.
class AvatarFallbackTest < ApplicationSystemTestCase
  test "a photo that fails to load is replaced by the person's initials" do
    users(:two).update!(avatar_url: "/no-such-photo.png")
    MealCook.find_or_create_by!(meal: meals(:upcoming_meal), user: users(:two)) { |cook| cook.role = "helper" }
    sign_in_as(users(:one))
    visit meal_url(meals(:upcoming_meal))

    assert_selector ".avatar span", text: "MD", visible: true
    assert_no_selector ".avatar img[src='/no-such-photo.png']"
  end
end
