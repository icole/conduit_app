# A pre-loaded, repeating job within a workstream. Each period it produces one
# Task (an "instance") pre-assigned to its default responsible person.
class RecurringTask < ApplicationRecord
  include Discard::Model

  acts_as_tenant :community

  FREQUENCIES = { "weekly" => "Weekly", "biweekly" => "Every two weeks", "monthly" => "Monthly" }.freeze
  EFFORT_PRESETS = { "Small" => 15, "Medium" => 45, "Large" => 90 }.freeze

  belongs_to :workstream
  belongs_to :default_responsible_user, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User"
  has_many :instances, class_name: "Task", dependent: :nullify

  default_scope -> { kept }

  validates :title, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES.keys }
  validates :priority, inclusion: { in: Workstream::PRIORITIES }, allow_nil: true
  validates :estimated_minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }

  before_validation { self.starts_on ||= Date.current }
  before_validation { self.priority = nil if priority.blank? }

  def self.effort_bucket(minutes)
    return if minutes.blank?

    if minutes < 30 then "Small"
    elsif minutes < 60 then "Medium"
    else "Large"
    end
  end

  # "Small · ~15 min"
  def self.effort_label(minutes)
    return if minutes.blank?

    "#{effort_bucket(minutes)} · ~#{minutes} min"
  end

  def effective_priority = priority.presence || workstream.priority
  def frequency_label = FREQUENCIES[frequency]
  def covered? = default_responsible_user_id.present?

  # Makes sure every recurring task in an open workstream has its instance for
  # the period containing +date+.
  def self.generate_instances!(date = Date.current)
    joins(:workstream).merge(Workstream.open).find_each { |recurring| recurring.instance_for(date) }
  end

  # This period's Task, created (pre-assigned to the default responsible
  # person) the first time it's asked for.
  def instance_for(date = Date.current)
    period = period_for(date)
    instances.find_or_create_by!(period_start: period.begin) do |task|
      task.title = title
      task.description = description
      task.workstream = workstream
      task.user = created_by
      task.assigned_to_user = default_responsible_user
      task.estimated_minutes = estimated_minutes
      task.due_date = period.end
      task.status = "active"
    end
  rescue ActiveRecord::RecordNotUnique
    instances.find_by!(period_start: period.begin)
  end

  # The date range of the period containing +date+.
  def period_for(date)
    case frequency
    when "monthly"
      date.beginning_of_month..date.end_of_month
    when "biweekly"
      anchor = starts_on.beginning_of_week
      offset = ((date.beginning_of_week - anchor).to_i / 7).floor
      start = anchor + (offset - offset % 2).weeks
      start..(start + 13.days)
    else
      date.beginning_of_week..date.end_of_week
    end
  end
end
