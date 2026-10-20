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
    task.release!(users(:one))
    delivered = nil
    fake = Struct.new(:task) { define_method(:deliver) { delivered = task } }

    ActsAsTenant.current_tenant = nil
    CoverageBroadcast.stub :released, ->(t) { fake.new(t) } do
      CoverageBroadcastJob.perform_now(task.community_id, task.id)
    end
    assert_equal task, delivered
  end

  test "everyone else with the app gets a push opening Available, and isn't asked again the next morning" do
    users(:one).push_devices.create!(token: "phone-1", platform: "apple")
    users(:two).push_devices.create!(token: "phone-2", platform: "google")
    task = recurring_tasks(:garbage_night).instance_for(Date.new(2026, 3, 5))
    task.release!(users(:one))
    clear_enqueued_jobs

    CoverageBroadcast.stub :released, ->(_) { Struct.new(:deliver).new(nil) } do
      CoverageBroadcastJob.perform_now(task.community_id, task.id)
    end
    pushes = enqueued_jobs.select { |job| job["job_class"] == "ApplicationPushNotificationJob" }.map { |job| job["arguments"][1] }
    assert_equal [ [ "Jane can't do this one", "Take out garbage & recycling · due Sun Mar 8", "/tasks?tab=available" ] ],
      pushes.map { |push| [ push["title"], push["body"], push.dig("data", "path") ] }
    assert_equal "task_needs_someone", users(:two).in_app_notifications.find_by!(notifiable: task).notification_type
    assert task.reload.unclaimed_reminder_sent_at
  end

  test "no push if someone picked it up before the job ran" do
    users(:two).push_devices.create!(token: "phone-2", platform: "google")
    task = recurring_tasks(:garbage_night).instance_for(Date.new(2026, 3, 5))
    task.release!(users(:one))
    task.claim!(users(:two))
    clear_enqueued_jobs

    CoverageBroadcast.stub :released, ->(_) { Struct.new(:deliver).new(nil) } do
      CoverageBroadcastJob.perform_now(task.community_id, task.id)
    end
    assert_empty enqueued_jobs.select { |job| job["job_class"] == "ApplicationPushNotificationJob" }
  end
end
