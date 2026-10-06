# One person on a task. Most tasks need one; some (meeting facilitation) two.
class TaskAssignment < ApplicationRecord
  acts_as_tenant :community
  has_paper_trail

  belongs_to :task
  belongs_to :user

  # Taking (or leaving) a task changes who it needs: freshen the apps' bells
  after_commit { BellBroadcastJob.about(task, user_id) }
  # Set when this person took a spot someone else released
  belongs_to :covering_for, class_name: "User", optional: true

  validates :user_id, uniqueness: { scope: :task_id }
end
