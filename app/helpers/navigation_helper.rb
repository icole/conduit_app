module NavigationHelper
  # Which section of the site each controller belongs to, for marking the
  # current one in the top bar and the phone tab bar
  SECTIONS = {
    home: %w[dashboard],
    tasks: %w[tasks workstreams recurring_tasks],
    calendar: %w[calendar calendar_events],
    meals: %w[meals meal_schedules],
    docs: %w[documents document_folders],
    chat: %w[chat],
    admin: %w[invitations users households dues email_logs]
  }.freeze

  # Heroicons has no fork and knife, so Meals uses Lucide's "utensils"
  # (lucide.dev, ISC licence), the same idea as the apps' Meals tab
  FORK_KNIFE = [
    "M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2",
    "M7 2v20",
    "M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"
  ].freeze

  # A tab bar icon: an outline at rest, solid (bolder, for the fork and knife)
  # when its tab is the current one
  def tab_icon(name, selected:)
    css = "#{selected ? 'icon-active' : 'icon-idle'} h-6 w-6"
    return heroicon(name, variant: selected ? :solid : :outline, options: { class: css }) unless name == "fork-knife"

    tag.svg safe_join(FORK_KNIFE.map { |d| tag.path(d: d) }),
      class: css, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
      "stroke-width": selected ? 2 : 1.5, "stroke-linecap": "round", "stroke-linejoin": "round",
      aria: { hidden: true }, data: { icon: "fork-knife" }
  end

  def current_section
    SECTIONS.find { |_, controllers| controllers.include?(controller_name) }&.first
  end

  def section_link_to(label, path, section, **options, &block)
    current = section == current_section
    options[:aria] = { current: ("page" if current) }
    block ? link_to(path, **options, &block) : link_to(label, path, **options)
  end
end
