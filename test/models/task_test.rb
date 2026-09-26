require "test_helper"

class TaskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  def setup
    @user = users(:one)
    @workstream = workstreams(:general)
  end

  test "should have default status of backlog" do
    task = Task.new(title: "Test Task", user: @user, workstream: @workstream)
    assert_equal "backlog", task.status
  end

  test "should validate status inclusion" do
    task = Task.new(title: "Test Task", user: @user, workstream: @workstream, status: "invalid")
    assert_not task.valid?
    assert_includes task.errors[:status], "is not included in the list"
  end

  test "should prioritize task from backlog" do
    task = Task.create!(title: "Test Task", user: @user, workstream: @workstream, status: "backlog")

    assert_equal "backlog", task.status
    assert_nil task.priority_order

    task.prioritize!

    assert_equal "active", task.status
    assert_not_nil task.priority_order
  end

  test "should move task to backlog" do
    task = Task.create!(title: "Test Task", user: @user, workstream: @workstream, status: "active", priority_order: 1)

    assert_equal "active", task.status
    assert_equal 1, task.priority_order

    task.move_to_backlog!

    assert_equal "backlog", task.status
    assert_nil task.priority_order
  end

  test "should detect overdue tasks" do
    task = Task.create!(
      title: "Overdue Task",
      user: @user, workstream: @workstream,
      due_date: 1.day.ago,
      status: "active"
    )

    assert task.overdue?
  end

  test "should detect tasks due soon" do
    task = Task.create!(
      title: "Due Soon Task",
      user: @user, workstream: @workstream,
      due_date: 3.days.from_now,
      status: "active"
    )

    assert task.due_soon?
  end

  test "should not mark completed tasks as overdue" do
    task = Task.create!(
      title: "Completed Overdue Task",
      user: @user, workstream: @workstream,
      due_date: 1.day.ago,
      status: "active"  # Start as active
    )

    # Then mark as completed
    task.update!(status: "completed")

    assert_not task.overdue?
  end

  test "should assign next priority order when prioritizing" do
    # Create two existing active tasks
    task1 = Task.create!(title: "Task 1", user: @user, workstream: @workstream, status: "active", priority_order: 1)
    task2 = Task.create!(title: "Task 2", user: @user, workstream: @workstream, status: "active", priority_order: 2)

    # Create a backlog task
    backlog_task = Task.create!(title: "Backlog Task", user: @user, workstream: @workstream, status: "backlog")

    # Prioritize the backlog task
    backlog_task.prioritize!

    # Should get priority order 3 (next after existing tasks)
    assert_equal 3, backlog_task.priority_order
  end

  test "should scope tasks correctly" do
    backlog_task = Task.create!(title: "Backlog Task", user: @user, workstream: @workstream, status: "backlog")
    active_task = Task.create!(title: "Active Task", user: @user, workstream: @workstream, status: "active", priority_order: 1)
    completed_task = Task.create!(title: "Completed Task", user: @user, workstream: @workstream, status: "completed")
    overdue_task = Task.create!(
      title: "Overdue Task",
      user: @user, workstream: @workstream,
      status: "active",
      due_date: 1.day.ago,
      priority_order: 2
    )

    assert_includes Task.backlog, backlog_task
    assert_includes Task.active, active_task
    assert_includes Task.completed, completed_task
    assert_includes Task.overdue, overdue_task
    assert_includes Task.prioritized, active_task
  end

  test "should auto-activate tasks with assignment or due date" do
    # Task with assignment should be active
    assigned_task = Task.create!(
      title: "Assigned Task",
      user: @user, workstream: @workstream,
      assigned_to_user: @user
    )
    assert_equal "active", assigned_task.status
    assert_not_nil assigned_task.priority_order

    # Task with due date should be active
    due_task = Task.create!(
      title: "Due Task",
      user: @user, workstream: @workstream,
      due_date: 1.week.from_now
    )
    assert_equal "active", due_task.status
    assert_not_nil due_task.priority_order

    # Regular task should stay in backlog
    backlog_task = Task.create!(
      title: "Regular Task",
      user: @user, workstream: @workstream
    )
    assert_equal "backlog", backlog_task.status
    assert_nil backlog_task.priority_order
  end

  test "requires a workstream (no orphan tasks)" do
    task = Task.new(title: "Loose task", user: @user)
    assert_not task.valid?
    assert task.errors[:workstream].any?
  end

  test "cannot be added to a closed workstream" do
    workstream = workstreams(:front_yard)
    workstream.close!
    task = Task.new(title: "Late addition", user: @user, workstream: workstream)
    assert_not task.valid?
    assert task.errors[:workstream].any?
  end

  test "effective priority comes from the recurring task, then the workstream" do
    task = Task.new(title: "T", user: @user, workstream: workstreams(:garbage))
    assert_equal "essential", task.effective_priority

    task.recurring_task = recurring_tasks(:pantry_restock)
    task.workstream = workstreams(:common_house)
    assert_equal "important", task.effective_priority
  end

  test "estimated minutes must be positive when present" do
    task = Task.new(title: "T", user: @user, workstream: @workstream, estimated_minutes: 0)
    assert_not task.valid?
    task.estimated_minutes = nil
    assert task.valid?
  end

  test "completing a task records who completed it and when" do
    task = Task.create!(title: "T", user: @user, workstream: @workstream, assigned_to_user: users(:two))
    Current.set(user: users(:two)) { task.update!(status: "completed") }

    assert_equal users(:two), task.completed_by
    assert_not_nil task.completed_at
  end

  test "completion falls back to the assignee when there is no current user" do
    task = Task.create!(title: "T", user: @user, workstream: @workstream, assigned_to_user: users(:two))
    task.update!(status: "completed")
    assert_equal users(:two), task.completed_by
  end

  test "reopening a completed task clears the completion record" do
    task = tasks(:completed_task)
    task.update!(completed_by: @user, completed_at: 1.day.ago)
    task.update!(status: "active")
    assert_nil task.completed_by
    assert_nil task.completed_at
  end

  test "open scope excludes completed tasks" do
    assert_includes Task.open, tasks(:one)
    assert_not_includes Task.open, tasks(:completed_task)
  end

  test "release! hands one instance back to the queue without touching the default person" do
    recurring = recurring_tasks(:garbage_night)
    task = recurring.instance_for(Date.new(2026, 3, 5))

    assert task.release!(users(:one))
    task.reload
    assert_nil task.assigned_to_user
    assert_equal users(:one), task.released_by
    assert_not_nil task.released_at
    assert_equal users(:one), recurring.reload.default_responsible_user
    assert_includes Task.available, task
  end

  test "only the assignee can release a task" do
    task = tasks(:assigned_task) # assigned to two
    assert_not task.release!(users(:one))
    assert_equal users(:two), task.reload.assigned_to_user
  end

  test "claim! assigns open, unassigned work to the claimer" do
    task = tasks(:one)
    assert task.claim!(users(:three))
    assert_equal users(:three), task.reload.assigned_to_user
    assert_equal "active", task.status
  end

  test "claimed work can't be claimed again" do
    task = tasks(:assigned_task)
    assert_not task.claim!(users(:three))
    assert_equal users(:two), task.reload.assigned_to_user
  end

  test "available is open, unassigned work in open workstreams, essential first" do
    nice = Task.create!(title: "Nice", user: @user, workstream: @workstream, due_date: Date.current)
    Workstream.where(id: @workstream.id).update_all(priority: "nice_to_have")
    essential = Task.create!(title: "Essential", user: @user, workstream: workstreams(:garbage))
    closed = Task.create!(title: "In closed project", user: @user, workstream: workstreams(:front_yard))
    workstreams(:front_yard).close!

    queue = Task.available_queue
    assert_equal "Essential", queue.first.title
    assert_includes queue, nice
    assert_not_includes queue, closed
    assert_not_includes queue, tasks(:assigned_task)
    assert_not_includes queue, tasks(:completed_task)
    assert_operator queue.index(essential), :<, queue.index(nice)
  end

  test "a task created as completed stays completed even with a due date" do
    task = Task.create!(title: "Already done", user: @user, workstream: @workstream, due_date: Date.current, status: "completed")
    assert task.completed?
  end

  test "a governance task with a single holder can't be released to the queue" do
    task = Task.create!(title: "Monthly bookkeeping", user: @user, workstream: workstreams(:treasurer), assigned_to_user: users(:one))
    assert_not task.releasable?
    assert_not task.release!(users(:one))
    assert_equal users(:one), task.reload.assigned_to_user
  end

  test "a co-held governance task can be released, without posting to the community chat" do
    task = Task.create!(title: "Build the agenda", user: @user, workstream: workstreams(:facilitators), assigned_to_user: users(:two))
    assert task.releasable?
    assert_no_enqueued_jobs(only: CoverageBroadcastJob) { assert task.release!(users(:two)) }
    assert_nil task.reload.assigned_to_user
  end

  test "released governance work is in the queue only for the role's holders, and only they can claim it" do
    task = Task.create!(title: "Build the agenda", user: @user, workstream: workstreams(:facilitators))

    assert_includes Task.available_queue(users(:three)), task
    assert_not_includes Task.available_queue(users(:one)), task
    assert_not_includes Task.available_queue, task

    assert_not task.claim!(users(:one))
    assert task.claim!(users(:three))
  end
end
