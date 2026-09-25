module TasksHelper
  PRIORITY_BADGE_CLASSES = {
    "essential" => "badge-error",
    "important" => "badge-warning",
    "nice_to_have" => "badge-ghost"
  }.freeze

  def priority_badge(priority, size: "badge-sm")
    tag.span Workstream.priority_label(priority), class: "badge #{size} #{PRIORITY_BADGE_CLASSES[priority]} whitespace-nowrap"
  end

  # Ongoing Operations are blue, One-Time Projects amber, wherever they appear.
  # Class names are spelled out in full so Tailwind can find them.
  def workstream_tag(workstream, size: "badge-sm")
    color = workstream.ongoing? ? "badge-info" : "badge-warning"
    link_to workstream.name, workstream_path(workstream),
            class: "badge #{size} badge-outline #{color} whitespace-nowrap hover:badge-soft",
            data: { turbo_frame: "_top" }
  end

  def workstream_type_badge(workstream, size: "badge-sm")
    color = workstream.ongoing? ? "badge-info" : "badge-warning"
    tag.span workstream.type_label, class: "badge #{size} #{color} whitespace-nowrap"
  end

  def workstream_accent_class(workstream)
    workstream.ongoing? ? "border-l-info" : "border-l-warning"
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
end
