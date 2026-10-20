require "test_helper"

# A recurring job its last person handed off: everyone hears, once, and the
# bell entry settles when someone takes it on.
class HandoffBroadcastJobTest < ActiveJob::TestCase
  setup do
    @recurring = recurring_tasks(:garbage_night)
    @recurring.instance_for
    @jane = users(:one)
    @mike = users(:two)
    @jane.push_devices.create!(token: "phone-1", platform: "apple")
    @mike.push_devices.create!(token: "phone-2", platform: "google")
  end

  def pushes
    enqueued_jobs.select { |job| job["job_class"] == "ApplicationPushNotificationJob" }.map { |job| job["arguments"][1] }
  end

  def announce
    @recurring.hand_off!(@jane)
    clear_enqueued_jobs
    CoverageBroadcast.stub(:handed_off, ->(_) { Struct.new(:deliver).new(nil) }) do
      HandoffBroadcastJob.perform_now(@recurring.community_id, @recurring.id)
    end
  end

  test "everyone else with the app gets a push opening Available" do
    announce
    assert_equal [ [ "Jane is handing off a job", "Take out garbage & recycling · weekly", "/tasks?tab=available" ] ],
      pushes.map { |push| [ push["title"], push["body"], push.dig("data", "path") ] }
  end

  test "it goes in everyone else's bell until someone takes it on" do
    announce
    entry = @mike.in_app_notifications.find_by!(notifiable: @recurring)
    assert_equal "job_needs_someone", entry.notification_type
    assert_not entry.addressed?
    assert_not @jane.in_app_notifications.exists?(notifiable: @recurring)

    @recurring.take_on!(users(:three))
    assert entry.reload.addressed?
  end

  test "posts it to the coverage chat" do
    delivered = nil
    @recurring.hand_off!(@jane)
    CoverageBroadcast.stub(:handed_off, ->(recurring) { delivered = recurring; Struct.new(:deliver).new(nil) }) do
      HandoffBroadcastJob.perform_now(@recurring.community_id, @recurring.id)
    end
    assert_equal @recurring, delivered
  end

  test "nothing if someone took it on before the job ran" do
    @recurring.hand_off!(@jane)
    @recurring.take_on!(@mike)
    clear_enqueued_jobs
    CoverageBroadcast.stub(:handed_off, ->(_) { flunk "no chat post" }) do
      HandoffBroadcastJob.perform_now(@recurring.community_id, @recurring.id)
    end
    assert_empty pushes
  end
end
