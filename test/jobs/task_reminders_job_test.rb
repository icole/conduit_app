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

  # One push per person per morning, however much there is
  def pushes_to(token)
    enqueued_jobs.select { |job| job["job_class"] == "ApplicationPushNotificationJob" }
      .select { |job| job["arguments"][2].to_s.include?(ApplicationPushDevice.find_by!(token: token).to_global_id.to_s) }
      .map { |job| job["arguments"][1] }
  end

  test "several things in a morning come as one summary push, opening My Tasks" do
    task_due(Date.new(2026, 10, 7)).update!(title: "Take out the bins")
    task_due(Date.new(2026, 10, 7)).update!(title: "Restock the pantry")
    task_due(Date.new(2026, 10, 6)).update!(title: "Sweep the porch")
    task_due(Date.new(2026, 10, 8), people: []).update!(title: "Wash the bins")
    task_due(Date.new(2026, 10, 9), people: []).update!(title: "Mow the lawn")

    at_local(7, 8) { TaskRemindersJob.perform_now }
    mine = pushes_to("phone-1")
    assert_equal 1, mine.size
    assert_equal "2 due today, 1 overdue · 2 need someone", mine.first["title"]
    assert_equal "Restock the pantry, Take out the bins, and 1 more", mine.first["body"]
    assert_equal "/tasks?tab=my", mine.first.dig("data", "path")
  end

  test "someone with only unclaimed tasks gets one push about them, opening Available" do
    two = users(:two)
    two.push_devices.create!(token: "phone-2", platform: "google")
    task_due(Date.new(2026, 10, 8), people: []).update!(title: "Wash the bins")
    task_due(Date.new(2026, 10, 9), people: []).update!(title: "Mow the lawn")

    at_local(7, 8) { TaskRemindersJob.perform_now }
    theirs = pushes_to("phone-2")
    assert_equal [ [ "2 tasks need someone", "Wash the bins and Mow the lawn" ] ], theirs.map { |push| push.values_at("title", "body") }
    assert_equal "/tasks?tab=available", theirs.first.dig("data", "path")
  end

  test "a task that comes due later in the day gets its own push on the next run" do
    at_local(7, 8) { TaskRemindersJob.perform_now }
    assert_empty pushes
    task_due(Date.new(2026, 10, 7))
    at_local(7, 11) { TaskRemindersJob.perform_now }
    assert_equal [ "Due today" ], pushes.map { |push| push["title"] }
  end

  # CON-72: reminders also go in the bell, one per task, for everyone,
  # with the app or without
  def bell(user) = ActsAsTenant.with_tenant(@community) { user.in_app_notifications.order(:created_at).map { |n| [ n.notification_type, n.title, n.notifiable ] } }

  test "a due task goes in the bell, then turns overdue there rather than adding another" do
    task = task_due(Date.new(2026, 10, 7))
    at_local(7, 8) { TaskRemindersJob.perform_now }
    assert_equal [ [ "task_due", "Due today", task ] ], bell(@one)

    at_local(8, 8) { TaskRemindersJob.perform_now }
    assert_equal [ [ "task_due", "Overdue", task ] ], bell(@one)
  end

  test "the due reminder takes over the bell entry for being put on the task" do
    task = task_due(Date.new(2026, 10, 7))
    TaskPush.assigned(task, @one, by: users(:two))
    at_local(7, 8) { TaskRemindersJob.perform_now }

    assert_equal [ [ "task_due", "Due today", task ] ], bell(@one)
  end

  test "people without the app get the bell, not a push" do
    no_phone = users(:two)
    task = task_due(Date.new(2026, 10, 7), people: [ no_phone ])
    at_local(7, 8) { TaskRemindersJob.perform_now }

    assert_equal [ [ "task_due", "Due today", task ] ], bell(no_phone)
    assert_empty pushes
  end

  test "work nobody is on goes in everyone's bell as needing someone" do
    task = task_due(Date.new(2026, 10, 8), people: [])
    at_local(7, 8) { TaskRemindersJob.perform_now }

    assert_equal [ [ "task_needs_someone", "Needs someone", task ] ], bell(users(:two)).last(1)
  end
end
