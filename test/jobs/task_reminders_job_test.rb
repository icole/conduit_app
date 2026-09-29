require "test_helper"

# Push reminders for tasks: the morning a task is due, and once the morning
# after if it's still open. Each person on it gets each reminder once.
class TaskRemindersJobTest < ActiveJob::TestCase
  setup do
    @community = communities(:crow_woods)
    @community.update!(time_zone: "America/Los_Angeles")
    @one = users(:one)
    @phone = @one.push_devices.create!(token: "phone-1", platform: "apple")
  end

  def at_local(day, hour, min = 5, &block)
    travel_to(ActiveSupport::TimeZone["America/Los_Angeles"].local(2026, 10, day, hour, min), &block)
  end

  def task_due(date, people: [ @one ], **attrs)
    ActsAsTenant.with_tenant(@community) do
      Task.create!(title: "Take out the bins", user: @one, workstream: workstreams(:garbage), due_date: date, assignees: people, **attrs)
    end
  end

  def pushes
    enqueued_jobs.select { |job| job["job_class"] == "ApplicationPushNotificationJob" }
      .map { |job| job["arguments"][1] }
  end

  test "the morning a task is due, everyone on it gets a reminder, once" do
    task = task_due(Date.new(2026, 10, 7))
    at_local(7, 8) { TaskRemindersJob.perform_now }
    assert_equal [ [ "Due today", "Take out the bins" ] ], pushes.map { |push| push.values_at("title", "body") }
    assert_equal "/tasks?tab=my", pushes.first.dig("data", "path")

    at_local(7, 9) { TaskRemindersJob.perform_now }
    assert_equal 1, pushes.size, "not twice"
    assert task.task_assignments.find_by!(user: @one).due_reminder_sent_at
  end

  test "nothing before 8am in the community's time zone" do
    task_due(Date.new(2026, 10, 7))
    at_local(7, 7, 55) { TaskRemindersJob.perform_now }
    assert_empty pushes
  end

  test "the morning after, a task still open gets one overdue reminder" do
    task_due(Date.new(2026, 10, 6))
    at_local(7, 8) { TaskRemindersJob.perform_now }
    assert_equal [ [ "Overdue", "Take out the bins was due yesterday" ] ], pushes.map { |push| push.values_at("title", "body") }

    at_local(8, 8) { TaskRemindersJob.perform_now }
    assert_equal 1, pushes.size, "only the morning after, not every day"
  end

  test "finished tasks, tasks nobody is on, and deleted tasks get no due reminders" do
    task_due(Date.new(2026, 10, 7), status: "completed")
    task_due(Date.new(2026, 10, 7), people: []) # gets "Needs someone" instead (below)
    task_due(Date.new(2026, 10, 7)).discard
    at_local(7, 8) { TaskRemindersJob.perform_now }
    assert_empty pushes.map { |push| push["title"] } - [ "Needs someone" ]
  end

  test "each person on a shared task gets their own reminder, on each of their phones" do
    two = users(:two)
    two.push_devices.create!(token: "phone-2", platform: "google")
    two.push_devices.create!(token: "tablet-2", platform: "apple")
    task_due(Date.new(2026, 10, 7), people: [ @one, two ])

    at_local(7, 8) { TaskRemindersJob.perform_now }
    assert_equal 3, pushes.size
  end

  test "people without the app are skipped, and not reminded later when they install it" do
    task = task_due(Date.new(2026, 10, 7), people: [ users(:three) ])
    at_local(7, 8) { TaskRemindersJob.perform_now }
    assert_empty pushes
    assert task.task_assignments.find_by!(user: users(:three)).due_reminder_sent_at
  end

  # Unclaimed: open work nobody is on, due within two days
  def unclaimed_titles
    pushes.select { |push| push["title"] == "Needs someone" }.map { |push| push["body"] }
  end

  test "a task nobody is on, due within two days, goes to everyone with the app, once" do
    two = users(:two)
    two.push_devices.create!(token: "phone-2", platform: "google")
    task = task_due(Date.new(2026, 10, 9), people: [])

    at_local(7, 8) { TaskRemindersJob.perform_now }
    assert_equal [ "Take out the bins · due Fri Oct 9", "Take out the bins · due Fri Oct 9" ], unclaimed_titles
    assert_equal "/tasks?tab=available", pushes.find { |push| push["title"] == "Needs someone" }.dig("data", "path")

    at_local(8, 8) { TaskRemindersJob.perform_now }
    assert_equal 2, unclaimed_titles.size, "once per task"
    assert task.reload.unclaimed_reminder_sent_at
  end

  test "no unclaimed push for tasks due later, taken, finished, or without a due date" do
    task_due(Date.new(2026, 10, 10), people: [])
    task_due(Date.new(2026, 10, 8))
    task_due(Date.new(2026, 10, 8), people: [], status: "completed")
    task_due(nil, people: [])
    at_local(7, 8) { TaskRemindersJob.perform_now }
    assert_empty unclaimed_titles
  end

  test "whoever released it isn't asked to pick it back up" do
    task = task_due(Date.new(2026, 10, 8), people: [ @one ])
    ActsAsTenant.with_tenant(@community) { task.update!(assignees: [], released_by: @one, released_at: Time.current) }
    at_local(7, 8) { TaskRemindersJob.perform_now }
    assert_empty unclaimed_titles
  end

  test "unclaimed governance work goes only to the role's holders" do
    three = users(:three) # holds Meeting Facilitators with two
    three.push_devices.create!(token: "phone-3", platform: "apple")
    ActsAsTenant.with_tenant(@community) do
      Task.create!(title: "Facilitate the meeting", user: @one, workstream: workstreams(:facilitators), due_date: Date.new(2026, 10, 8))
    end
    at_local(7, 8) { TaskRemindersJob.perform_now }
    assert_equal [ "Facilitate the meeting · due Thu Oct 8" ], unclaimed_titles
  end
end
