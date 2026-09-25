require "test_helper"

class GenerateTaskInstancesJobTest < ActiveJob::TestCase
  test "creates this period's instance for every community's recurring tasks" do
    ActsAsTenant.current_tenant = nil
    assert_difference -> { ActsAsTenant.without_tenant { Task.where.not(recurring_task_id: nil).count } }, 2 do
      GenerateTaskInstancesJob.perform_now
    end
    assert_no_difference -> { ActsAsTenant.without_tenant { Task.count } } do
      GenerateTaskInstancesJob.perform_now
    end
  end
end
