require "test_helper"

class CommunityMealSettingsTest < ActiveSupport::TestCase
  setup do
    @community = communities(:crow_woods)
  end

  test "meal_buffer_weeks defaults to 6" do
    assert_equal 6, @community.meal_buffer_weeks
  end

  test "meal_buffer_weeks can be set via settings" do
    @community.update!(settings: { "meal_buffer_weeks" => 8 })
    assert_equal 8, @community.meal_buffer_weeks
  end

  test "meal_buffer_weeks returns integer" do
    @community.update!(settings: { "meal_buffer_weeks" => "10" })
    assert_equal 10, @community.meal_buffer_weeks
  end

  test "meal_buffer_weeks setter updates settings" do
    @community.meal_buffer_weeks = 12
    @community.save!
    @community.reload
    assert_equal 12, @community.meal_buffer_weeks
  end
end
