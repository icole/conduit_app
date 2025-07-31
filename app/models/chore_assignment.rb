class ChoreAssignment < ApplicationRecord
  belongs_to :chore
  belongs_to :user

  validates :active, inclusion: { in: [true, false] }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Deactivate other assignments when activating this one
  before_save :deactivate_others, if: :active?

  private

  def deactivate_others
    return unless active?
    
    # Deactivate other active assignments for this chore
    chore.chore_assignments.active.where.not(id: id).update_all(
      active: false,
      end_date: Date.current
    )
  end
end