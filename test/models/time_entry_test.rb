require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @role = roles(:garden_maven)
    @task = tasks(:one)
  end

  test "should require user" do
    entry = TimeEntry.new(hours: 2.0, logged_on: Date.current, entry_type: "task")
    assert_not entry.valid?
    assert_includes entry.errors[:user], "must exist"
  end

  test "should require hours" do
    entry = TimeEntry.new(user: @user, logged_on: Date.current, entry_type: "reconciliation", role: @role)
    assert_not entry.valid?
    assert_includes entry.errors[:hours], "can't be blank"
  end

  test "should require positive hours" do
    entry = TimeEntry.new(user: @user, hours: -1, logged_on: Date.current, entry_type: "reconciliation", role: @role)
    assert_not entry.valid?
    assert_includes entry.errors[:hours], "must be greater than 0"
  end

  test "should require logged_on" do
    entry = TimeEntry.new(user: @user, hours: 2.0, entry_type: "reconciliation", role: @role)
    assert_not entry.valid?
    assert_includes entry.errors[:logged_on], "can't be blank"
  end

  test "should require entry_type" do
    entry = TimeEntry.new(user: @user, hours: 2.0, logged_on: Date.current, role: @role)
    assert_not entry.valid?
    assert_includes entry.errors[:entry_type], "can't be blank"
  end

  test "should validate entry_type inclusion" do
    entry = TimeEntry.new(user: @user, hours: 2.0, logged_on: Date.current, entry_type: "invalid", role: @role)
    assert_not entry.valid?
    assert_includes entry.errors[:entry_type], "is not included in the list"
  end

  test "should allow valid task time entry" do
    entry = TimeEntry.new(
      user: @user,
      task: @task,
      role: @role,
      hours: 1.5,
      logged_on: Date.current,
      entry_type: "task"
    )
    assert entry.valid?
  end

  test "should allow valid reconciliation entry" do
    entry = TimeEntry.new(
      user: @user,
      role: @role,
      hours: 3.0,
      logged_on: Date.current,
      entry_type: "reconciliation",
      note: "Side conversations and informal maintenance"
    )
    assert entry.valid?
  end

  test "should scope by entry_type" do
    assert TimeEntry.task_entries.all? { |e| e.entry_type == "task" }
    assert TimeEntry.reconciliation_entries.all? { |e| e.entry_type == "reconciliation" }
  end

  test "should scope by month" do
    entry = time_entries(:maven_task_entry)
    results = TimeEntry.for_month(entry.logged_on.year, entry.logged_on.month)
    assert_includes results, entry
  end

  test "should calculate total hours for a role" do
    total = TimeEntry.where(role: @role).sum(:hours)
    assert total > 0
  end
end
