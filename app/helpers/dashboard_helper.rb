module DashboardHelper
  # "3 meals this week · 2 still need a cook", from the dashboard's timeline
  def week_summary(timeline_items, until_time: 7.days.from_now)
    meals = timeline_items.filter_map { |item| item[:meal] if item[:type] == :meal && item[:start_time] < until_time }
    return "No community meals on the calendar this week" if meals.empty?

    cookless = meals.count(&:needs_head_cook?)
    parts = [ pluralize(meals.size, "meal") + " this week" ]
    parts << "#{cookless} still #{cookless == 1 ? 'needs' : 'need'} a cook" if cookless.positive?
    parts.join(" · ")
  end
end
