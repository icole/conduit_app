# Push notifications to the people on a task. Tapping one opens My Tasks in
# the app. Nothing is sent to someone without the app (no registered phone).
class TaskPush
  MY_TASKS = "/tasks?tab=my".freeze

  def self.due_today(task, user)
    deliver(user, title: "Due today", body: task.title)
  end

  def self.overdue(task, user)
    deliver(user, title: "Overdue", body: "#{task.title} was due yesterday")
  end

  def self.assigned(task, user, by:)
    deliver(user, title: "#{by.name.split.first} put you on a task", body: task.title)
  end

  def self.deliver(user, title:, body:)
    devices = user.push_devices.to_a
    return if devices.empty?

    ApplicationPushNotification.with_data(path: MY_TASKS)
      .new(title: title, body: body, thread_id: "tasks")
      .deliver_later_to(devices)
  end
  private_class_method :deliver
end
