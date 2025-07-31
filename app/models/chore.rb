class Chore < ApplicationRecord
  belongs_to :proposed_by, class_name: "User"
  has_many :chore_assignments, dependent: :destroy
  has_many :assigned_users, through: :chore_assignments, source: :user
  has_many :chore_completions, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  validates :name, presence: true
  validates :frequency, inclusion: { in: %w[daily weekly biweekly monthly custom] }, allow_blank: true
  validates :frequency, presence: true, if: :active?
  validates :status, presence: true, inclusion: { in: %w[proposed active archived] }

  scope :proposed, -> { where(status: "proposed").order(created_at: :desc) }
  scope :active, -> { where(status: "active").order(next_due_date: :asc) }
  scope :archived, -> { where(status: "archived") }
  scope :due_today, -> { active.where(next_due_date: Date.current) }
  scope :overdue, -> { active.where("next_due_date < ?", Date.current) }
  scope :upcoming, -> { active.where("next_due_date >= ?", Date.current).order(:next_due_date) }

  # Get the current champion (active assignment)
  def current_champion
    chore_assignments.active.includes(:user).first&.user
  end

  # Check if a user is currently assigned
  def assigned_to?(user)
    chore_assignments.active.where(user: user).exists?
  end

  # Check if the chore needs a volunteer
  def needs_volunteer?
    active? && chore_assignments.active.empty?
  end

  # Status helpers
  def proposed?
    status == "proposed"
  end

  def active?
    status == "active"
  end

  def archived?
    status == "archived"
  end

  # Calculate next due date based on frequency
  def calculate_next_due_date(from_date = Date.current)
    return nil if frequency.blank?

    case frequency
    when "daily"
      from_date + 1.day
    when "weekly"
      from_date + 1.week
    when "biweekly"
      from_date + 2.weeks
    when "monthly"
      from_date + 1.month
    when "custom"
      # Handle custom frequency using frequency_details
      # For now, default to weekly
      from_date + 1.week
    end
  end

  # Mark as complete and update next due date
  def mark_complete!(user, notes: nil)
    transaction do
      chore_completions.create!(
        completed_by: user,
        completed_at: Time.current,
        notes: notes
      )
      update!(next_due_date: calculate_next_due_date)
    end
  end

  # Approve a proposed chore
  def approve!
    raise "Cannot approve chore without frequency" if frequency.blank?
    update!(status: "active", next_due_date: calculate_next_due_date)
  end

  # Archive a chore
  def archive!
    update!(status: "archived")
  end

  # Get completion count for a specific period
  def completions_count(period = nil)
    scope = chore_completions
    case period
    when :this_week
      scope = scope.where("completed_at >= ?", Date.current.beginning_of_week)
    when :this_month
      scope = scope.where("completed_at >= ?", Date.current.beginning_of_month)
    end
    scope.count
  end

  # Get last completion
  def last_completed_at
    chore_completions.order(completed_at: :desc).first&.completed_at
  end

  # For likes interface
  def likes_count
    likes.count
  end

  def liked_by?(user)
    return false unless user
    likes.exists?(user: user)
  end

  # For comments interface
  def comments_count
    comments.count
  end
end
