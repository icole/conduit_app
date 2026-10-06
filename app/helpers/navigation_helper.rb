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

  def current_section
    SECTIONS.find { |_, controllers| controllers.include?(controller_name) }&.first
  end

  def section_link_to(label, path, section, **options, &block)
    current = section == current_section
    options[:aria] = { current: ("page" if current) }
    block ? link_to(path, **options, &block) : link_to(label, path, **options)
  end
end
