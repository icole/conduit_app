class Task < ApplicationRecord
  acts_as_tenant :community

  belongs_to :user
  belongs_to :assigned_to_user, class_name: "User", optional: true

  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: %w[backlog active completed] }

  before_save :auto_set_status_and_priority, if: :new_record?

  # Default status is 'backlog'
  attribute :status, :string, default: "backlog"

  # Scopes for filtering tasks
  scope :backlog, -> { where(status: "backlog") }
  scope :active, -> { where(status: "active") }
  scope :pending, -> { where(status: "active") } # Keep for backward compatibility
  scope :completed, -> { where(status: "completed") }
  scope :prioritized, -> { where(status: "active").order(:priority_order, :created_at) }
  scope :with_due_date, -> { where.not(due_date: nil) }
  scope :overdue, -> { where("due_date < ? AND status != 'completed'", Date.current) }
  scope :due_soon, -> { where("due_date >= ? AND due_date <= ? AND status != 'completed'", Date.current, 7.days.from_now) }

  # Order tasks by priority for active, creation date for others
  scope :ordered, -> {
    case_sql = <<~SQL
      CASE#{' '}
        WHEN status = 'active' THEN priority_order
        ELSE 999999
      END ASC,
      created_at DESC
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
end
