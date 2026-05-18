class RoleAssignment < ApplicationRecord
  has_paper_trail

  belongs_to :role
  belongs_to :user

  ASSIGNMENT_TYPES = %w[holder backup co_holder].freeze

  validates :assignment_type, presence: true, inclusion: { in: ASSIGNMENT_TYPES }
  validates :starts_at, presence: true

  after_save :update_role_vacancy
  after_destroy :update_role_vacancy

  scope :active_assignments, -> { where(active: true) }
  scope :holders, -> { where(assignment_type: "holder") }
  scope :backups, -> { where(assignment_type: "backup") }
  scope :co_holders, -> { where(assignment_type: "co_holder") }
  scope :expiring_soon, -> { where(active: true).where("ends_at <= ?", 30.days.from_now.to_date) }

  def expired?
    ends_at.present? && ends_at < Date.current
  end

  def expiring_soon?
    ends_at.present? && ends_at <= 30.days.from_now.to_date && ends_at >= Date.current
  end

  private

  def update_role_vacancy
    role.update_vacancy!
  end
end
