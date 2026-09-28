class Task < ApplicationRecord
  include Discardable
  include EstimatedEffort

  # Audited: who created a task, who reassigned it, and what it said before.
  # Soft deletes are updates, so discarding is recorded too.
  has_paper_trail

  acts_as_tenant :community

  belongs_to :user
  belongs_to :workstream
  belongs_to :recurring_task, optional: true
  # Who's doing it: one person, or several sharing it (meeting facilitation).
  # people_needed is left over from a first version and dropped next release.
  self.ignored_columns += [ "people_needed" ]
  has_many :task_assignments, dependent: :destroy
  # dependent: :destroy so taking someone off runs the assignment's audit trail
  has_many :assignees, -> { order(:name) }, through: :task_assignments, source: :user, dependent: :destroy

  belongs_to :completed_by, class_name: "User", optional: true
  belongs_to :released_by, class_name: "User", optional: true

  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: %w[backlog active completed] }
  validates :estimated_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :workstream_must_be_open, if: -> { workstream && (new_record? || workstream_id_changed?) }

  before_save :auto_set_status_and_priority, if: :new_record?
  before_save :track_completion, if: :status_changed?
  before_create :set_created_by

  # Default status is 'backlog'
  attribute :status, :string, default: "backlog"

  # Scopes for filtering tasks
  scope :backlog, -> { where(status: "backlog") }
  scope :active, -> { where(status: "active") }
  scope :pending, -> { where(status: "active") } # Keep for backward compatibility
  scope :completed, -> { where(status: "completed") }
  scope :open, -> { where.not(status: "completed") }
  scope :prioritized, -> { where(status: "active").order(:priority_order, :created_at) }
  scope :with_due_date, -> { where.not(due_date: nil) }
  scope :overdue, -> { where("tasks.due_date < ? AND tasks.status != 'completed'", Date.current) }
  scope :due_soon, -> { where("tasks.due_date >= ? AND tasks.due_date <= ? AND tasks.status != 'completed'", Date.current, 7.days.from_now) }

  scope :assigned_to, ->(user) { where(id: TaskAssignment.where(user_id: user).select(:task_id)) }
  scope :unassigned, -> { where.not(id: TaskAssignment.select(:task_id)) }

  # Open work nobody is on, in open workstreams: the Available queue.
  scope :available, -> { open.unassigned.joins(:workstream).merge(Workstream.open) }

  # Order tasks by priority for active, creation date for others
  scope :ordered, -> {
    case_sql = <<~SQL
      CASE#{' '}
        WHEN tasks.status = 'active' THEN tasks.priority_order
        ELSE 999999
      END ASC,
      tasks.created_at DESC
    SQL
    order(Arel.sql(case_sql))
  }

  # Override default scope to use ordered scope
  default_scope { ordered }

  # Move task from backlog to active with priority
  def prioritize!(priority_order = nil)
    new_priority = priority_order || next_priority_order
    update!(status: "active", priority_order: new_priority)
  end

  # Move task back to backlog
  def move_to_backlog!
    update!(status: "backlog", priority_order: nil)
  end

  # The Available queue, essential work first, then soonest due.
  # Governance work only shows to the role's holders.
  def self.available_queue(user = nil)
    tasks = available.includes(:recurring_task, :released_by, workstream: :owners).select do |task|
      !task.workstream.governance? || task.workstream.owned_by?(user)
    end
    tasks.sort_by do |task|
      [ Workstream.priority_rank(task.effective_priority), task.due_date || Date.new(9999), task.created_at ]
    end
  end

  # Someone's on it, it's open, and letting go leaves it with someone who can
  # do it: another person already on it, or the queue. A governance role
  # hands off only among its holders, so one held by one person can't go.
  def releasable?
    return false if completed? || assignees.empty?

    assignees.size > 1 || !workstream.governance? || workstream.owners.size > 1
  end

  # One person can't do it this time. If others are on it, it stays with
  # them. If they were the last, it goes back to the queue and (except for
  # governance, which stays among the role's holders) a note goes to the
  # community's coverage chat channel. The recurring task's people are untouched.
  def release!(by)
    assignment = task_assignments.find_by(user_id: by.id)
    return false unless assignment && releasable?

    to_queue = assignees.size == 1
    transaction do
      assignment.destroy!
      update!(released_by: by, released_at: Time.current) if to_queue
    end
    CoverageBroadcastJob.perform_later(community_id, id) if to_queue && !workstream.governance?
    true
  end

  def claimable_by?(user)
    !workstream.governance? || workstream.owned_by?(user)
  end

  def claim!(user)
    return false unless claimable_by?(user)

    with_lock do
      return false if completed? || assignees.any?

      task_assignments.create!(user: user, covering_for: released_by)
      update!(status: "active")
    end
    true
  end

  def assigned_to?(user) = user.present? && assignees.include?(user)

  # Shorthand for a one-person task: its first assignee, or assign just this one
  def assigned_to_user = assignees.first
  def assigned_to_user=(user)
    self.assignees = Array(user)
  end

  def effective_priority
    recurring_task&.effective_priority || workstream.priority
  end

  def completed? = status == "completed"
  def recurring? = recurring_task_id.present?

  # Check if task is overdue
  def overdue?
    due_date && due_date < Date.current && status != "completed"
  end

  # Check if task is due soon (within 7 days)
  def due_soon?
    due_date && due_date <= 7.days.from_now.to_date && due_date >= Date.current && status != "completed"
  end

  private

  def next_priority_order
    max_priority = Task.active.maximum(:priority_order) || 0
    max_priority + 1
  end

  # Automatically determine status based on task attributes
  def auto_determine_status
    if assignees.any? || due_date.present?
      "active"
    else
      "backlog"
    end
  end

  # Callback to auto-set status and priority for new tasks
  def auto_set_status_and_priority
    # If task has assignment or due date, make it active
    return if completed?

    if assignees.any? || due_date.present?
      self.status = "active"
      self.priority_order = next_priority_order if priority_order.blank?
    end
  end

  def workstream_must_be_open
    errors.add(:workstream, "is closed") if workstream.closed?
  end

  def track_completion
    if completed?
      self.completed_at ||= Time.current
      self.completed_by ||= Current.user || assigned_to_user || user
    else
      self.completed_at = nil
      self.completed_by = nil
    end
  end

  def set_created_by
    self.created_by ||= user
  end
end
