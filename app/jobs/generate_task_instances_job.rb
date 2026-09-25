# Creates each recurring task's instance for the current period, pre-assigned
# to its default responsible person. The Tasks page also does this on demand.
class GenerateTaskInstancesJob < ApplicationJob
  queue_as :default

  def perform
    Community.find_each do |community|
      ActsAsTenant.with_tenant(community) do
        RecurringTask.generate_instances!(Time.current.in_time_zone(community.time_zone).to_date)
      end
    end
  end
end
