# Notifications about tasks. Each task gets an entry in the person's bell
# (CON-72), whether or not they have the app; the push, which opens My Tasks
# (or Available, for work nobody is on), only goes to registered phones.
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

    due.each { |task| remember(user, "task_due", task, "Due today", task.title, MY_TASKS) }
    overdue.each { |task| remember(user, "task_due", task, "Overdue", "#{task.title} was due yesterday", MY_TASKS) }
    unclaimed.each { |task| remember(user, "task_needs_someone", task, *needs_someone(task), AVAILABLE) }

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
    else needs_someone(unclaimed)
    end
  end

  # "A and B", or "A, B, and 3 more"
  def self.names(tasks)
    titles = tasks.map(&:title)
    titles.size <= 2 ? titles.to_sentence : "#{titles.first(2).join(', ')}, and #{titles.size - 2} more"
  end

  def self.assigned(task, user, by:)
    title = "#{by.name.split.first} put you on a task"
    remember(user, "task_assigned", task, title, task.title, MY_TASKS)
    deliver(user, title: title, body: task.title)
  end

  def self.unclaimed(task, user)
    title, body = needs_someone(task)
    remember(user, "task_needs_someone", task, title, body, AVAILABLE)
    deliver(user, title: title, body: body, path: AVAILABLE)
  end

  def self.needs_someone(task) = [ "Needs someone", "#{task.title} · due #{task.due_date.strftime('%a %b %-d')}" ]

  # One entry per task: a reminder updates the one already waiting (being put
  # on it, then due, then overdue) and shows it unread again, not adds another
  def self.remember(user, kind, task, title, body, path)
    notification = user.in_app_notifications.needs_you.find_by(notifiable: task) || user.in_app_notifications.new(notifiable: task)
    notification.update!(notification_type: kind, title: title, body: body, action_url: path, read: false, read_at: nil)
  end

  def self.deliver(user, title:, body:, path: MY_TASKS)
    PhonePush.deliver(user, title: title, body: body, path: path, thread: "tasks")
  end
  private_class_method :deliver, :single, :names, :needs_someone, :remember
end
