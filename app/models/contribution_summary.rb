# The Contribution tab for one period: completed effort by household against a
# fair-share reference, how much essential work got done, and where help is
# needed. Framed around the community, not a ranking.
class ContributionSummary
  attr_reader :period

  def initialize(period, community = ActsAsTenant.current_tenant)
    @period = period
    @zone = ActiveSupport::TimeZone[community.time_zone] || Time.zone
  end

  # Households with members, alphabetically.
  def households
    @households ||= Household.where(id: User.where.not(household_id: nil).select(:household_id)).order(:name).to_a
  end

  def minutes_for(household)
    minutes_by_household.fetch(household.id, 0)
  end

  def total_minutes
    minutes_by_household.except(nil).values.sum
  end

  def fair_share_minutes
    households.any? ? total_minutes / households.size : 0
  end

  # Contributed by members who aren't in a household yet.
  def unaffiliated_minutes
    minutes_by_household.fetch(nil, 0)
  end

  # Of the essential work due so far this period, the percentage that got done.
  def essential_coverage_percent
    due = essential_due_so_far
    return if due.empty?

    (due.count(&:completed?) * 100.0 / due.size).round
  end

  # [name, detail] pairs for essential areas nobody is holding.
  def areas_needing_help
    unowned = Workstream.open.unowned.where(priority: "essential").order(:name).map do |workstream|
      [ workstream.name, "No owner assigned" ]
    end

    unheld = RecurringTask.joins(:workstream).merge(Workstream.open)
      .includes(:workstream, :responsibles).order(:title)
      .select { |recurring| !recurring.covered? && recurring.effective_priority == "essential" }
      .map do |recurring|
        gap = recurring.responsibles.empty? ? "Nobody responsible" : "Needs #{recurring.open_spots} more"
        [ recurring.title, "#{gap} · #{recurring.workstream.name}" ]
      end

    unowned + unheld
  end

  def recently_completed(limit = 10)
    completed_in_period.includes(:completed_by, :assignees, :workstream).reorder(completed_at: :desc).limit(limit)
  end

  private

  def completed_in_period
    starts = @zone.local(period.start_date.year, period.start_date.month)
    ends = @zone.local(period.next.start_date.year, period.next.start_date.month)
    Task.completed.where(completed_at: starts...ends)
  end

  # Everyone on a finished task gets its full time (two facilitators each
  # spent the evening on it); a task nobody was on counts for whoever did it.
  def minutes_by_household
    @minutes_by_household ||= begin
      shared = completed_in_period.joins(task_assignments: :user).reorder(nil)
        .group("users.household_id").sum("COALESCE(tasks.estimated_minutes, 0)")
      solo = completed_in_period.where.missing(:task_assignments).joins(:completed_by).reorder(nil)
        .group("users.household_id").sum("COALESCE(tasks.estimated_minutes, 0)")
      shared.merge(solo) { |_household, a, b| a + b }
    end
  end

  def essential_due_so_far
    today = @zone.today
    last_day = [ period.end_date, today ].min
    return [] if last_day < period.start_date

    Task.where(due_date: period.start_date..last_day).includes(:workstream, :recurring_task)
      .select { |task| task.effective_priority == "essential" }
  end
end
