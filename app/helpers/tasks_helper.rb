module TasksHelper
  PRIORITY_BADGE_CLASSES = {
    "essential" => "badge-error text-on-error",
    "important" => "badge-warning",
    "nice_to_have" => "badge-ghost"
  }.freeze

  def priority_badge(priority, size: "badge-sm")
    tag.span Workstream.priority_label(priority), class: "badge #{size} #{PRIORITY_BADGE_CLASSES[priority]} whitespace-nowrap"
  end

  # Governance is neutral grey, Ongoing Operations blue, One-Time Projects
  # amber, wherever they appear. Class names are spelled out in full so
  # Tailwind can find them.
  def workstream_tag(workstream, size: "badge-sm")
    # Tinted fill with a dark label: the theme's yellow and blue are too light
    # to read as text on the page.
    color = if workstream.governance?
      "border-neutral/40 bg-neutral/10 text-base-content hover:bg-neutral/20"
    elsif workstream.ongoing?
      "border-info/50 bg-info/10 text-info-ink hover:bg-info/20"
    else
      "border-warning/70 bg-warning/15 text-warning-ink hover:bg-warning/25"
    end
    link_to workstream.name, workstream_path(workstream),
            class: "badge #{size} #{color} whitespace-nowrap",
            data: { turbo_frame: "_top" }
  end

  def workstream_type_badge(workstream, size: "badge-sm")
    color = if workstream.governance? then "badge-neutral"
    elsif workstream.ongoing? then "badge-info"
    else "badge-warning"
    end
    tag.span workstream.type_label, class: "badge #{size} #{color} whitespace-nowrap"
  end

  def workstream_accent_class(workstream)
    if workstream.governance? then "border-l-neutral"
    elsif workstream.ongoing? then "border-l-info"
    else "border-l-warning"
    end
  end

  # The coloured edge only from sm up; on phones the section heading carries it.
  def workstream_accent_class_from_sm(workstream)
    if workstream.governance? then "sm:border-l-neutral"
    elsif workstream.ongoing? then "sm:border-l-info"
    else "sm:border-l-warning"
    end
  end

  # Governance roles are required rather than ranked.
  def required_badge(size: "badge-sm")
    tag.span "Required", class: "badge #{size} badge-neutral whitespace-nowrap"
  end

  def workstream_priority_badge(workstream, size: "badge-sm")
    workstream.governance? ? required_badge(size: size) : priority_badge(workstream.priority, size: size)
  end

  def task_priority_badge(task, size: "badge-sm")
    task.workstream.governance? ? required_badge(size: size) : priority_badge(task.effective_priority, size: size)
  end

  def effort_badge(minutes)
    return if minutes.blank?

    tag.span RecurringTask.effort_label(minutes), class: "badge badge-sm badge-ghost whitespace-nowrap"
  end

  def effort_options
    RecurringTask::EFFORT_PRESETS.map { |bucket, minutes| [ "#{bucket} · ~#{minutes} min", minutes ] }
  end

  def priority_options(include_inherit: false)
    options = Workstream::PRIORITY_LABELS.map { |value, label| [ label, value ] }
    include_inherit ? [ [ "Same as workstream", "" ] ] + options : options
  end

  # 585 -> "9.8 hrs"
  def hours(minutes)
    format("%.1f hrs", minutes / 60.0)
  end

  PRIORITY_DOT_CLASSES = { "essential" => "bg-error", "important" => "bg-warning", "nice_to_have" => "bg-base-300" }.freeze

  # A coloured dot and the level's name, for compact rows on phones.
  def priority_dot(priority)
    safe_join([
      tag.span(class: "inline-block w-2 h-2 rounded-full #{PRIORITY_DOT_CLASSES[priority]}", aria: { hidden: true }),
      Workstream.priority_label(priority)
    ], " ")
  end

  # "Due Sat" this week, "Due Oct 2" further out, "Overdue · Sep 20" past.
  def due_label(date, today: Date.current)
    return if date.blank?
    return "Overdue · #{date.strftime('%b %-d')}" if date < today
    return "Due today" if date == today

    date <= today + 6 ? "Due #{date.strftime('%a')}" : "Due #{date.strftime('%b %-d')}"
  end

  # One grouped list on phones (rows split by hairlines), separate cards from sm up.
  def task_list_classes(priority: nil)
    border = priority == "essential" ? "border-error/50" : "border-base-200"
    "rounded-box border #{border} bg-base-100 divide-y divide-base-200 " \
      "sm:rounded-none sm:border-0 sm:bg-transparent sm:divide-y-0 sm:space-y-2"
  end
end
