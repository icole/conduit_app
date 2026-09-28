# One of the people a recurring task goes to each period.
class RecurringTaskResponsible < ApplicationRecord
  acts_as_tenant :community

  belongs_to :recurring_task
  belongs_to :user

  validates :user_id, uniqueness: { scope: :recurring_task_id }
end
