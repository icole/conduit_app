class Task < ApplicationRecord
  include Discardable

  acts_as_tenant :community

  belongs_to :user
  belongs_to :workstream
  belongs_to :recurring_task, optional: true
  belongs_to :assigned_to_user, class_name: "User", optional: true
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

  # Open, unclaimed work in open workstreams: the Available queue.
  scope :available, -> { open.where(assigned_to_user_id: nil).joins(:workstream).merge(Workstream.open) }

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
  def self.available_queue
    available.includes(:workstream, :recurring_task, :released_by).sort_by do |task|
      [ Workstream.priority_rank(task.effective_priority), task.due_date || Date.new(9999), task.created_at ]
    end
  end

  # The assignee can't do it this time: back to the queue, and a note to the
  # community's coverage chat channel. The recurring default is untouched.
  def release!(by)
    return false unless assigned_to_user_id == by.id && !completed?

    update!(assigned_to_user: nil, released_by: by, released_at: Time.current)
    CoverageBroadcastJob.perform_later(community_id, id)
    true
  end

  def claim!(user)
    with_lock do
      return false if assigned_to_user_id.present? || completed?

      update!(assigned_to_user: user, status: "active")
    end
    true
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
    if assigned_to_user_id.present? || due_date.present?
      "active"
    else
      "backlog"
    end
  end

  # Callback to auto-set status and priority for new tasks
  def auto_set_status_and_priority
    # If task has assignment or due date, make it active
    if assigned_to_user_id.present? || due_date.present?
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
