# Push notifications about tasks. Tapping one opens My Tasks (or Available,
# for work nobody is on) in the app. Nothing is sent to someone without the
# app (no registered phone).
class TaskPush
  MY_TASKS = "/tasks?tab=my".freeze
  AVAILABLE = "/tasks?tab=available".freeze

  # The one morning push (TaskRemindersJob): what's due today and overdue for
  # this person, and open work nobody is on. A single item keeps its own
  # wording; several become a summary. Opens My Tasks, or Available when
  # it's only unclaimed work.
  def self.morning(user, due: [], overdue: [], unclaimed: [])
    mine = due.sort_by(&:title) + overdue.sort_by(&:title)
    unclaimed = unclaimed.sort_by { |task| [ task.due_date, task.title ] }
    return if mine.empty? && unclaimed.empty?

    title, body =
      if mine.size + unclaimed.size == 1
        single(due.first, overdue.first, unclaimed.first)
      elsif mine.empty?
        [ "#{unclaimed.size} tasks need someone", names(unclaimed) ]
      else
        counts = [ ("#{due.size} due today" if due.any?), ("#{overdue.size} overdue" if overdue.any?) ].compact.join(", ")
        counts += " · #{unclaimed.size} need someone" if unclaimed.any?
        [ counts, names(mine) ]
      end

    deliver(user, title: title, body: body, path: mine.any? ? MY_TASKS : AVAILABLE)
  end

  def self.single(due, overdue, unclaimed)
    if due then [ "Due today", due.title ]
    elsif overdue then [ "Overdue", "#{overdue.title} was due yesterday" ]
    else [ "Needs someone", "#{unclaimed.title} · due #{unclaimed.due_date.strftime('%a %b %-d')}" ]
    end
  end

  # "A and B", or "A, B, and 3 more"
  def self.names(tasks)
    titles = tasks.map(&:title)
    titles.size <= 2 ? titles.to_sentence : "#{titles.first(2).join(', ')}, and #{titles.size - 2} more"
  end

  def self.assigned(task, user, by:)
    deliver(user, title: "#{by.name.split.first} put you on a task", body: task.title)
  end

  def self.unclaimed(task, user)
    deliver(user, title: "Needs someone", body: "#{task.title} · due #{task.due_date.strftime('%a %b %-d')}", path: AVAILABLE)
  end

  def self.deliver(user, title:, body:, path: MY_TASKS)
    devices = user.push_devices.to_a
    return if devices.empty?

    ApplicationPushNotification.with_data(path: path)
      .new(title: title, body: body, thread_id: "tasks")
      .deliver_later_to(devices)
  end
  private_class_method :deliver, :single, :names
end
