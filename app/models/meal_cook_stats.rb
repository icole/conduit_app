# The Meals "Cooks" tab: how shared meals are going this year, who to thank,
# and where a cook is still needed. Framed around the community, not a
# ranking: nobody's count is shown except to themselves. Head cooks only;
# helpers aren't really used.
class MealCookStats
  Mine = Struct.new(:count, :last_on, :next_on)
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

  # One person's own cooking: meals held (all time), the last one, and the next
  def for(user)
    theirs = held_cooking.where(user: user)
    Mine.new(theirs.count, local_date(theirs.maximum("meals.scheduled_at")),
             local_date(upcoming_cooking.where(user: user).minimum("meals.scheduled_at")))
  end

  # For whoever asks people to cook: past cooks with nothing coming up, the
  # longest since their turn first
  def resting_cooks
    last_by_user = held_cooking.where.not(user_id: upcoming_cooking.select(:user_id)).group(:user_id).maximum("meals.scheduled_at")
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
