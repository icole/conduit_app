class CoverageBroadcastJob < ApplicationJob
  queue_as :default

  def perform(community_id, task_id)
    community = Community.find(community_id)
    ActsAsTenant.with_tenant(community) do
      task = Task.find_by(id: task_id)
      return unless task&.assignees&.none?

      CoverageBroadcast.released(task).deliver
      TaskPush.released(task)
    end
  end
end
