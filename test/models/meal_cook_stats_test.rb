require "test_helper"

class MealCookStatsTest < ActiveSupport::TestCase
  # Well clear of the fixtures' meals, which sit around today's date
  setup { travel_to Time.zone.local(2027, 6, 15, 12) }

  def meal(on, cook: nil, status: "completed")
    shared = Meal.create!(title: "Dinner", scheduled_at: on.change(hour: 18), rsvp_deadline: on.change(hour: 12), status: status)
    shared.meal_cooks.create!(user: cook, role: "head_cook") if cook
    shared
  end

  test "counts this year's shared meals, how many had a cook, and how many people cooked" do
    meal Time.zone.local(2027, 2, 7), cook: users(:three)
    meal Time.zone.local(2027, 3, 7), cook: users(:four)
    meal Time.zone.local(2027, 4, 4), cook: users(:three)
    meal Time.zone.local(2027, 5, 2)
    meal Time.zone.local(2027, 5, 9), status: "cancelled"
    meal Time.zone.local(2026, 12, 6), cook: users(:five) # last year

    stats = MealCookStats.new
    assert_equal 2027, stats.year
    assert_equal 4, stats.meals_shared
    assert_equal 3, stats.meals_with_a_cook
    assert_equal [ users(:four), users(:three) ].sort_by(&:name), stats.cooks
  end

  test "open meals are upcoming ones nobody has signed up to cook" do
    open = meal Time.zone.local(2027, 6, 20), status: "upcoming"
    meal Time.zone.local(2027, 6, 27), cook: users(:three), status: "upcoming"

    assert_equal [ open ], MealCookStats.new.open_meals
  end

  test "your own cooking: how often, when last, and when next" do
    meal Time.zone.local(2026, 11, 1), cook: users(:three)
    meal Time.zone.local(2027, 4, 4), cook: users(:three)
    meal Time.zone.local(2027, 7, 4), cook: users(:three), status: "upcoming"

    mine = MealCookStats.new.for(users(:three))
    assert_equal 2, mine.count, "meals held, all time"
    assert_equal Date.new(2027, 4, 4), mine.last_on
    assert_equal Date.new(2027, 7, 4), mine.next_on

    nobody = MealCookStats.new.for(users(:six))
    assert_equal [ 0, nil, nil ], [ nobody.count, nobody.last_on, nobody.next_on ]
  end

  test "for whoever does the asking: past cooks with nothing coming up, longest since their turn first" do
    meal Time.zone.local(2027, 1, 3), cook: users(:three)
    meal Time.zone.local(2027, 5, 2), cook: users(:four)
    meal Time.zone.local(2027, 2, 7), cook: users(:five)
    meal Time.zone.local(2027, 7, 4), cook: users(:five), status: "upcoming"

    resting = MealCookStats.new.resting_cooks
    ours = resting.map(&:user) & [ users(:three), users(:four), users(:five) ] # the fixtures' cooks are in there too
    assert_equal [ users(:three), users(:four) ], ours
    assert_not_includes resting.map(&:user), users(:five), "already signed up"
    assert_equal Date.new(2027, 1, 3), resting.find { |row| row.user == users(:three) }.last_on
  end
end
