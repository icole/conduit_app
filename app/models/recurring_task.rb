# A pre-loaded, repeating job within a workstream. Each period it produces one
# Task (an "instance") pre-assigned to its default responsible person.
class RecurringTask < ApplicationRecord
  include Discard::Model
  include EstimatedEffort

  acts_as_tenant :community

  FREQUENCIES = {
    "weekly" => "Weekly", "biweekly" => "Every two weeks", "monthly" => "Monthly",
    "quarterly" => "Quarterly", "yearly" => "Yearly"
  }.freeze

  belongs_to :workstream
  # Who each period's task goes to: one person, or several sharing it
  has_many :recurring_task_responsibles, dependent: :destroy
  has_many :responsibles, -> { order(:name) }, through: :recurring_task_responsibles, source: :user
  belongs_to :created_by, class_name: "User"
  has_many :instances, class_name: "Task", dependent: :nullify

  default_scope -> { kept }

  # Its open work goes with it; completed instances stay as contribution history.
  after_discard { instances.open.find_each(&:discard) }

  validates :title, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES.keys }
  validates :priority, inclusion: { in: Workstream::PRIORITIES }, allow_nil: true
  validates :estimated_minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }
  # Weekly and every-two-weeks tasks fall due on this day (Date#wday, 0 = Sunday)
  validates :due_wday, inclusion: { in: 0..6 }

  before_validation { self.starts_on ||= Date.current }
  before_validation { self.priority = nil if priority.blank? }

  after_update :move_current_instance, if: :saved_change_to_due_wday?

  # Admins, the workstream's owners, and whoever set it up can change it.
  def manageable_by?(user) = user.admin? || workstream.owned_by?(user) || created_by_id == user.id

  def effective_priority = priority.presence || workstream.priority
  def frequency_label = FREQUENCIES[frequency]
  def covered? = responsibles.any?

  # Shorthand for a one-person job: its first person, or just this one
  def default_responsible_user = responsibles.first
  def default_responsible_user=(user)
    self.responsibles = Array(user)
  end

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
      assignees: responsibles.to_a,
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
      # Two of those weeks, keeping the rhythm set by starts_on
      anchor = week_start(starts_on)
      offset = (week_start(date) - anchor).to_i / 7
      start = anchor + (offset - offset % 2).weeks
      start..(start + 13.days)
    else
      week_start(date)..(week_start(date) + 6.days)
    end
  end

  private

  # A week runs from the day after the due day to the due day: Monday to
  # Sunday by default.
  def week_start(date)
    first_wday = (due_wday + 1) % 7
    date - ((date.wday - first_wday) % 7)
  end

  # A new due day moves this period's open task with it, rather than leaving it
  # on the old day and adding another task for the new period.
  def move_current_instance
    return unless frequency.in?(%w[weekly biweekly])

    period = period_for(Date.current)
    current = instances.open.where(due_date: Date.current..).order(:due_date).first
    return if current.nil? || instances.with_discarded.where(period_start: period.begin).where.not(id: current.id).exists?

    current.update!(period_start: period.begin, due_date: period.end)
  end

  # The period's instance, deleted or not; nil when it was deleted.
  def existing_instance(period)
    task = Task.with_discarded.find_by(recurring_task_id: id, period_start: period.begin)
    task if task&.kept?
  end
end
