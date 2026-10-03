# The Meals "Cooks" tab: where a cook is still needed, how shared meals are
# going this year, what's been on the menu, and enough about your own cooking
# to tell whether it's your turn. Framed around the community, not a ranking:
# nobody's count is shown except to themselves. Head cooks only; helpers
# aren't really used.
class MealCookStats
  Mine = Struct.new(:count, :this_year, :last_on, :next_on)
  Resting = Struct.new(:user, :last_on, :count)

  attr_reader :year

  def initialize(community = ActsAsTenant.current_tenant)
    @zone = ActiveSupport::TimeZone[community.time_zone] || Time.zone
    @year = @zone.today.year
  end

  # Upcoming meals nobody has signed up to cook, soonest first
  def open_meals
    Meal.needs_cooks.to_a
  end

  def meals_shared
    held_this_year.count
  end

  def meals_with_a_cook
    held_this_year.where(id: head_cooks.select(:meal_id)).count
  end

  # Everyone who head-cooked a shared meal this year, alphabetically
  def cooks
    User.where(id: head_cooks.where(meal_id: held_this_year.select(:id)).select(:user_id)).order(:name).to_a
  end

  # One person's own cooking: meals held (all time and this year), the last
  # one, and the next
  def for(user)
    theirs = held_cooking.where(user: user)
    Mine.new(theirs.count, theirs.merge(held_this_year).count, local_date(theirs.maximum("meals.scheduled_at")),
             local_date(upcoming_cooking.where(user: user).minimum("meals.scheduled_at")))
  end

  # How often a turn comes round: this year's cooks shared across its pace of
  # cooked meals. nil before anything's been cooked this year.
  def weeks_between_turns
    return if meals_with_a_cook.zero?

    (cooks.size * weeks_so_far / meals_with_a_cook).round
  end

  # When someone counts as resting: half the usual gap between turns, so a cook
  # from a week or two ago isn't on the list; 4 weeks before there's a pace
  def rest_weeks
    every = weeks_between_turns
    every ? (every / 2.0).ceil : 4
  end

  # How many meals a typical cook has cooked this year
  def typical_turns_this_year
    cooks.any? ? (meals_with_a_cook.to_f / cooks.size).round : 0
  end

  # The last few shared meals with a menu, newest first
  def recent_menus(limit: 4)
    held.joins(:rich_text_menu).where.not(action_text_rich_texts: { body: [ nil, "" ] })
      .includes(:rich_text_menu, meal_cooks: :user).order(scheduled_at: :desc).limit(limit).to_a
  end

  # For whoever asks people to cook: past cooks with nothing coming up whose
  # last turn was at least +at_least+ ago, the longest since their turn first
  def resting_cooks(at_least: rest_weeks.weeks)
    last_by_user = held_cooking.where.not(user_id: upcoming_cooking.select(:user_id))
      .group(:user_id).having("MAX(meals.scheduled_at) <= ?", Time.current - at_least).maximum("meals.scheduled_at")
    counts = held_cooking.group(:user_id).count
    users = User.where(id: last_by_user.keys).index_by(&:id)
    last_by_user.sort_by { |_, at| at }.map { |id, at| Resting.new(users[id], local_date(at), counts[id]) }
  end

  private

  def held
    Meal.where("meals.scheduled_at < ?", Time.current).where.not(status: "cancelled").reorder(nil)
  end

  def held_this_year
    start = @zone.local(year)
    held.where(scheduled_at: start...start.next_year)
  end

  def weeks_so_far
    (Time.current - @zone.local(year)) / 1.week
  end

  def head_cooks
    MealCook.where(role: "head_cook")
  end

  def held_cooking
    head_cooks.joins(:meal).merge(held)
  end

  def upcoming_cooking
    head_cooks.joins(:meal).merge(Meal.upcoming.reorder(nil))
  end

  def local_date(time)
    time&.in_time_zone(@zone)&.to_date
  end
end
