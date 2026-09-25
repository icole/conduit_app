# A pre-loaded, repeating job within a workstream. Each period it produces one
# Task (an "instance") pre-assigned to its default responsible person.
class RecurringTask < ApplicationRecord
  include Discard::Model

  acts_as_tenant :community

  FREQUENCIES = {
    "weekly" => "Weekly", "biweekly" => "Every two weeks", "monthly" => "Monthly",
    "quarterly" => "Quarterly", "yearly" => "Yearly"
  }.freeze
  EFFORT_PRESETS = { "Small" => 15, "Medium" => 45, "Large" => 90 }.freeze

  belongs_to :workstream
  belongs_to :default_responsible_user, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User"
  has_many :instances, class_name: "Task", dependent: :nullify

  default_scope -> { kept }

  # Its open work goes with it; completed instances stay as contribution history.
  after_discard { instances.open.find_each(&:discard) }

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
  # person) the first time it's asked for. nil if that period's instance was
  # deleted: it stays deleted rather than coming back.
  def instance_for(date = Date.current)
    period = period_for(date)
    existing = Task.with_discarded.find_by(recurring_task_id: id, period_start: period.begin)
    return existing.kept? ? existing : nil if existing

    instances.create!(
      period_start: period.begin,
      title: title,
      description: description,
      workstream: workstream,
      user: created_by,
      assigned_to_user: default_responsible_user,
      estimated_minutes: estimated_minutes,
      due_date: period.end,
      status: "active"
    )
  rescue ActiveRecord::RecordNotUnique
    existing_instance(period)
  end

  # The date range of the period containing +date+.
  def period_for(date)
    case frequency
    when "monthly"
      date.beginning_of_month..date.end_of_month
    when "quarterly"
      date.beginning_of_quarter..date.end_of_quarter
    when "yearly"
      # Anchored on starts_on, so a yearly job falls due in its season: a
      # period starting Nov 1 is due Oct 31.
      years = date.year - starts_on.year
      start = starts_on >> (12 * years)
      start = starts_on >> (12 * (years - 1)) if start > date
      start..((start >> 12) - 1)
    when "biweekly"
      anchor = starts_on.beginning_of_week
      offset = ((date.beginning_of_week - anchor).to_i / 7).floor
      start = anchor + (offset - offset % 2).weeks
      start..(start + 13.days)
    else
      date.beginning_of_week..date.end_of_week
    end
  end

  private

  # The period's instance, deleted or not; nil when it was deleted.
  def existing_instance(period)
    task = Task.with_discarded.find_by(recurring_task_id: id, period_start: period.begin)
    task if task&.kept?
  end
end
