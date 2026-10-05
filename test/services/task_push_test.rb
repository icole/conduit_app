require "test_helper"

# CON-72: being put on a task lands in the bell, with the app or without
class TaskPushTest < ActiveSupport::TestCase
  test "being put on a task goes in your bell, once per task" do
    task = Task.create!(title: "Fix the gate", user: users(:one), workstream: workstreams(:general), due_date: Date.current)
    2.times { TaskPush.assigned(task, users(:two), by: users(:one)) }

    entries = users(:two).in_app_notifications.where(notifiable: task)
    assert_equal [ [ "task_assigned", "#{users(:one).name.split.first} put you on a task", "Fix the gate" ] ],
      entries.map { |n| [ n.notification_type, n.title, n.body ] }
  end
end
