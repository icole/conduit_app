# One of the people a recurring task goes to each period.
class RecurringTaskResponsible < ApplicationRecord
  acts_as_tenant :community

  belongs_to :recurring_task
  belongs_to :user

  validates :user_id, uniqueness: { scope: :recurring_task_id }

  # Someone's on it again, however they got there: the handoff is settled
  after_create { recurring_task.update!(handed_off_by: nil, handed_off_at: nil) if recurring_task.handed_off_at }
end
