require "test_helper"

class TaskTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  test "should have default status of backlog" do
    task = Task.new(title: "Test Task", user: @user)
    assert_equal "backlog", task.status
  end

  test "should validate status inclusion" do
    task = Task.new(title: "Test Task", user: @user, status: "invalid")
    assert_not task.valid?
    assert_includes task.errors[:status], "is not included in the list"
  end

  test "should prioritize task from backlog" do
    task = Task.create!(title: "Test Task", user: @user, status: "backlog")

    assert_equal "backlog", task.status
    assert_nil task.priority_order

    task.prioritize!

    assert_equal "active", task.status
    assert_not_nil task.priority_order
  end

  test "should move task to backlog" do
    task = Task.create!(title: "Test Task", user: @user, status: "active", priority_order: 1)

    assert_equal "active", task.status
    assert_equal 1, task.priority_order

    task.move_to_backlog!

    assert_equal "backlog", task.status
    assert_nil task.priority_order
  end

  test "should detect overdue tasks" do
    task = Task.create!(
      title: "Overdue Task",
      user: @user,
      due_date: 1.day.ago,
      status: "active"
    )

    assert task.overdue?
  end

  test "should detect tasks due soon" do
    task = Task.create!(
      title: "Due Soon Task",
      user: @user,
      due_date: 3.days.from_now,
      status: "active"
    )

    assert task.due_soon?
  end

  test "should not mark completed tasks as overdue" do
    task = Task.create!(
      title: "Completed Overdue Task",
      user: @user,
      due_date: 1.day.ago,
      status: "active"  # Start as active
    )

    # Then mark as completed
    task.update!(status: "completed")

    assert_not task.overdue?
  end

  test "should assign next priority order when prioritizing" do
    # Create two existing active tasks
    task1 = Task.create!(title: "Task 1", user: @user, status: "active", priority_order: 1)
    task2 = Task.create!(title: "Task 2", user: @user, status: "active", priority_order: 2)

    # Create a backlog task
    backlog_task = Task.create!(title: "Backlog Task", user: @user, status: "backlog")

    # Prioritize the backlog task
    backlog_task.prioritize!

    # Should get priority order 3 (next after existing tasks)
    assert_equal 3, backlog_task.priority_order
  end

  test "should scope tasks correctly" do
    backlog_task = Task.create!(title: "Backlog Task", user: @user, status: "backlog")
    active_task = Task.create!(title: "Active Task", user: @user, status: "active", priority_order: 1)
    completed_task = Task.create!(title: "Completed Task", user: @user, status: "completed")
    overdue_task = Task.create!(
      title: "Overdue Task",
      user: @user,
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
      user: @user,
      assigned_to_user: @user
    )
    assert_equal "active", assigned_task.status
    assert_not_nil assigned_task.priority_order

    # Task with due date should be active
    due_task = Task.create!(
      title: "Due Task",
      user: @user,
      due_date: 1.week.from_now
    )
    assert_equal "active", due_task.status
    assert_not_nil due_task.priority_order

    # Regular task should stay in backlog
    backlog_task = Task.create!(
      title: "Regular Task",
      user: @user
    )
    assert_equal "backlog", backlog_task.status
    assert_nil backlog_task.priority_order
  end
end
