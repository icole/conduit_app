# Asks the community who can take on a recurring job its last person handed
# off: a post in the coverage chat channel and a push to everyone.
class HandoffBroadcastJob < ApplicationJob
  queue_as :default

  def perform(community_id, recurring_task_id)
    community = Community.find(community_id)
    ActsAsTenant.with_tenant(community) do
      recurring = RecurringTask.find_by(id: recurring_task_id)
      return unless recurring&.looking_for_someone?

      CoverageBroadcast.handed_off(recurring).deliver
      TaskPush.handed_off(recurring)
    end
  end
end
