require "test_helper"

class TasksHelperTest < ActionView::TestCase
  test "due_label is a weekday this week, a date further out, and flags the past" do
    today = Date.new(2026, 9, 24) # Thursday
    assert_equal "Due today", due_label(today, today: today)
    assert_equal "Due Sun", due_label(Date.new(2026, 9, 27), today: today)
    assert_equal "Due Wed", due_label(Date.new(2026, 9, 30), today: today)
    assert_equal "Due Oct 1", due_label(Date.new(2026, 10, 1), today: today)
    assert_equal "Overdue · Sep 20", due_label(Date.new(2026, 9, 20), today: today)
    assert_nil due_label(nil, today: today)
  end

  test "priority_dot pairs a coloured dot with the level's name" do
    html = priority_dot("essential")
    assert_includes html, "bg-error"
    assert_includes html, "Essential"
  end
end
