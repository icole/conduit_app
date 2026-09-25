require "test_helper"

class CoverageBroadcastJobTest < ActiveJob::TestCase
  test "releasing a task enqueues the broadcast" do
    task = recurring_tasks(:garbage_night).instance_for(Date.new(2026, 3, 5))
    assert_enqueued_with(job: CoverageBroadcastJob, args: [ task.community_id, task.id ]) do
      task.release!(users(:one))
    end
  end

  test "delivers within the task's community" do
    task = recurring_tasks(:garbage_night).instance_for(Date.new(2026, 3, 5))
    delivered = nil
    fake = Struct.new(:task) { define_method(:deliver) { delivered = task } }

    ActsAsTenant.current_tenant = nil
    CoverageBroadcast.stub :new, ->(t) { fake.new(t) } do
      CoverageBroadcastJob.perform_now(task.community_id, task.id)
    end
    assert_equal task, delivered
  end
end
