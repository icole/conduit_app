require "test_helper"

class RecurringTaskTest < ActiveSupport::TestCase
  setup do
    @recurring = recurring_tasks(:garbage_night)
  end

  test "requires a workstream, title and estimated effort" do
    recurring = RecurringTask.new
    assert_not recurring.valid?
    %i[workstream title estimated_minutes].each do |attr|
      assert recurring.errors[attr].any?, "expected an error on #{attr}"
    end
  end

  test "frequency must be weekly, biweekly or monthly" do
    @recurring.frequency = "daily"
    assert_not @recurring.valid?
  end

  test "priority is optional and falls back to the workstream's" do
    @recurring.priority = nil
    assert_equal @recurring.workstream.priority, @recurring.effective_priority

    @recurring.priority = "nice_to_have"
    assert_equal "nice_to_have", @recurring.effective_priority
  end

  test "covered when it has a default responsible person" do
    assert @recurring.covered?
    assert_not recurring_tasks(:pantry_restock).covered?
  end

  test "weekly periods start on Monday" do
    @recurring.frequency = "weekly"
    period = @recurring.period_for(Date.new(2026, 3, 5)) # Thursday
    assert_equal Date.new(2026, 3, 2), period.begin
    assert_equal Date.new(2026, 3, 8), period.end
  end

  test "biweekly periods are two weeks long, anchored on starts_on" do
    @recurring.frequency = "biweekly"
    @recurring.starts_on = Date.new(2026, 3, 2)
    assert_equal Date.new(2026, 3, 2)..Date.new(2026, 3, 15), @recurring.period_for(Date.new(2026, 3, 12))
    assert_equal Date.new(2026, 3, 16)..Date.new(2026, 3, 29), @recurring.period_for(Date.new(2026, 3, 16))
    assert_equal Date.new(2026, 2, 16)..Date.new(2026, 3, 1), @recurring.period_for(Date.new(2026, 2, 20))
  end

  test "monthly periods are calendar months" do
    @recurring.frequency = "monthly"
    assert_equal Date.new(2026, 2, 1)..Date.new(2026, 2, 28), @recurring.period_for(Date.new(2026, 2, 14))
  end

  test "effort bucket is Small, Medium or Large" do
    assert_equal "Small", RecurringTask.effort_bucket(15)
    assert_equal "Medium", RecurringTask.effort_bucket(45)
    assert_equal "Large", RecurringTask.effort_bucket(90)
    assert_nil RecurringTask.effort_bucket(nil)
  end
end
