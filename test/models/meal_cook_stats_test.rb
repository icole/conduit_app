require "test_helper"

class MealCookStatsTest < ActiveSupport::TestCase
  # Well clear of the fixtures' meals, which sit around today's date
  setup { travel_to Time.zone.local(2027, 6, 15, 12) }

  def meal(on, cook: nil, status: "completed", menu: nil)
    shared = Meal.create!(title: "Dinner", scheduled_at: on.change(hour: 18), rsvp_deadline: on.change(hour: 12), status: status, menu: menu)
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

    resting = MealCookStats.new.resting_cooks(at_least: 4.weeks)
    ours = resting.map(&:user) & [ users(:three), users(:four), users(:five) ] # the fixtures' cooks are in there too
    assert_equal [ users(:three), users(:four) ], ours
    assert_not_includes resting.map(&:user), users(:five), "already signed up"
    assert_equal Date.new(2027, 1, 3), resting.find { |row| row.user == users(:three) }.last_on
  end

  test "recently on the menu: the last few shared meals, newest first, with their cook" do
    meal Time.zone.local(2027, 5, 2), cook: users(:three), menu: "Lentil dal and greens"
    meal Time.zone.local(2027, 5, 9), cook: users(:four), menu: "Tacos with all the fixings"
    meal Time.zone.local(2027, 5, 16), status: "cancelled", menu: "Never happened"
    meal Time.zone.local(2027, 6, 20), cook: users(:five), status: "upcoming", menu: "Not yet"

    recent = MealCookStats.new.recent_menus(limit: 2)
    assert_equal [ "Tacos with all the fixings", "Lentil dal and greens" ], recent.map { |m| m.menu.to_plain_text }
    assert_equal users(:four), recent.first.head_cook
  end

  test "how often a turn comes round: cooks shared across the year's pace of meals" do
    # 2027 so far: 4 cooked meals in 24 weeks, shared by 2 cooks: a meal every 6 weeks, a turn every 12
    meal Time.zone.local(2027, 1, 3), cook: users(:three)
    meal Time.zone.local(2027, 2, 14), cook: users(:four)
    meal Time.zone.local(2027, 4, 4), cook: users(:three)
    meal Time.zone.local(2027, 5, 16), cook: users(:four)

    stats = MealCookStats.new
    assert_equal 12, stats.weeks_between_turns
    assert_equal 2, stats.typical_turns_this_year
    assert_equal 2, stats.for(users(:three)).this_year
  end

  test "no pace yet with nothing cooked this year" do
    assert_nil MealCookStats.new.weeks_between_turns
  end

  test "someone who cooked recently isn't listed as resting, however they're signed up" do
    meal Time.zone.local(2027, 1, 3), cook: users(:three)  # 23 weeks ago
    meal Time.zone.local(2027, 6, 6), cook: users(:four)   # last week

    resting = MealCookStats.new.resting_cooks(at_least: 4.weeks).map(&:user)
    assert_includes resting, users(:three)
    assert_not_includes resting, users(:four)
  end

  test "resting means at least half the usual gap between turns, or 4 weeks before there's a pace" do
    assert_equal 4, MealCookStats.new.rest_weeks

    # A turn every 12 weeks (see above), so resting starts at 6
    meal Time.zone.local(2027, 1, 3), cook: users(:three)
    meal Time.zone.local(2027, 2, 14), cook: users(:four)
    meal Time.zone.local(2027, 4, 4), cook: users(:three)
    meal Time.zone.local(2027, 5, 16), cook: users(:four)
    assert_equal 6, MealCookStats.new.rest_weeks
  end
end
