class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [ :edit, :update, :destroy, :release, :claim, :complete, :reopen ]
  before_action :set_discarded_task, only: [ :restore ]
  before_action :set_users, only: [ :index, :new, :edit, :create, :update ]

  TAB_LABELS = { "my" => "My Tasks", "available" => "Available", "all" => "All work", "contribution" => "Contribution" }.freeze
  TABS = TAB_LABELS.keys.freeze
  # Old names still land on their tab (links, bookmarks, a tab the apps remembered)
  TAB_ALIASES = { "coverage" => "all" }.freeze

  def index
    @task = Task.new

    # The old backlog / priority board's addresses: every open task, or the deleted ones
    if params[:view].present?
      return redirect_to tasks_path(tab: "all", list: params[:view] == "deleted" ? "deleted" : "tasks")
    end

    @tab = tab_named(params[:tab]) || remembered_tab || "my"
    session[:tasks_tab] = @tab if hotwire_native_app?
    RecurringTask.generate_instances!(Time.current.in_time_zone(current_community.time_zone).to_date)
    case @tab
    when "available" then load_available_tab
    when "all" then load_all_work_tab
    when "contribution" then load_contribution_tab
    else load_my_tab
    end
  end

  def new
    @task = Task.new(workstream_id: params[:workstream_id])
  end

  def create
    return create_recurring if params.dig(:task, :repeats).present?

    @task = current_user.tasks.build(task_params)
    new_ids = assignee_ids_param || []
    @task.assignees = User.where(id: new_ids)

    unless assignment_allowed?(@task, [], new_ids) && @task.save
      return respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("new_task", partial: "tasks/form", locals: { task: @task }) }
      end
    end

    notify_new_assignees(@task, new_ids)
    notice = "Task was successfully created."
    redirect_path = request.referer&.include?("tasks") ? tasks_path_for(@task) : dashboard_index_path
    # The apps' add-task sheet: close it and reload the screen beneath
    return close_native_sheet(notice:) if from_native_sheet?

    respond_to do |format|
      format.html { redirect_to redirect_path, notice: }
      format.turbo_stream { flash.now[:notice] = notice }
    end
  end

  def edit
    @return_to = return_to_path
  end

  def update
    @return_to = return_to_path
    old_ids = @task.assignee_ids
    new_ids = assignee_ids_param || old_ids
    @task.assign_attributes(task_params)

    saved = assignment_allowed?(@task, old_ids, new_ids) && Task.transaction do
      @task.assignees = User.where(id: new_ids) unless new_ids.sort == old_ids.sort
      @task.save || raise(ActiveRecord::Rollback)
    end

    if saved
      notify_new_assignees(@task, new_ids - old_ids)
      # The apps' edit sheet: close it and reload the screen beneath
      return close_native_sheet(notice: "Task was successfully updated.") if from_native_sheet?
      redirect_to @return_to, notice: "Task was successfully updated."
    else
      @task.assignees.reset
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.discard
    @redirect_path = request.referer&.include?("tasks") ? tasks_path : dashboard_index_path

    respond_to do |format|
      format.html { redirect_to @redirect_path, flash: { notice_with_undo: { message: "Task deleted.", undo_path: restore_task_path(@task) } } }
      format.turbo_stream { flash.now[:notice_with_undo] = { message: "Task deleted.", undo_path: restore_task_path(@task) } }
    end
  end

  def restore
    @task.undiscard
    # Back to wherever the Undo was tapped: a Tasks tab, a workstream, the dashboard
    redirect_back_or_to dashboard_index_path, notice: "Task restored."
  end

  # Ticking a task off. The toast's Undo reopens it.
  def complete
    return_to = return_to_path
    return redirect_to(return_to, alert: COMPLETION_REFUSED) unless can_change_completion?(@task)

    @task.update!(status: "completed")
    redirect_to return_to, flash: { notice_with_undo: { message: "Marked “#{@task.title}” done.",
                                                         undo_path: reopen_task_path(@task, return_to: return_to) } }
  end

  # Undo, or "Mark not done": back on the list, still with whoever had it.
  def reopen
    return_to = return_to_path
    return redirect_to(return_to, alert: COMPLETION_REFUSED) unless can_change_completion?(@task)

    @task.update!(status: "active")
    redirect_to return_to, notice: "“#{@task.title}” is back on the list."
  end

  def release
    if @task.release!(current_user)
      redirect_to tasks_path(tab: "my"), notice: "Released to the queue. We let the community know in chat."
    else
      redirect_to tasks_path(tab: "my"), alert: "Only the person it's assigned to can release a task."
    end
  end

  # Back to Available, or wherever the Claim button was (All tasks)
  def claim
    back = url_from(params[:return_to]) || tasks_path(tab: "available")
    if !@task.claimable_by?(current_user)
      redirect_to back, alert: "That's for the #{@task.workstream.name} to pick up."
    elsif @task.claim!(current_user)
      redirect_to back, notice: "It's yours. Find it under My Tasks."
    else
      redirect_to back, alert: "Someone already picked that one up."
    end
  end

  private

  COMPLETION_REFUSED = "Only the person doing it, or the workstream's owners, can change whether that's done.".freeze

  # Whoever has it (or finished it, or added it for nobody in particular),
  # plus the workstream's owners and admins.
  def can_change_completion?(task)
    return true if task.assigned_to?(current_user) || task.completed_by_id == current_user.id
    return true if task.assignees.empty? && task.user_id == current_user.id

    can_assign_others?(task.workstream)
  end

  RECURRING_ERROR_LABELS = { estimated_minutes: "Estimated effort", frequency: "Repeats", workstream: "Workstream", title: "Title" }.freeze

  # "Repeats" on the Add task form sets up a recurring task instead. Anyone
  # can; like assigning a task, only the workstream's owners (or an admin)
  # can make someone else responsible for it.
  def create_recurring
    @task = current_user.tasks.build(task_params)
    @repeats = params[:task][:repeats]

    responsible_ids = assignee_ids_param || []
    @task.assignees = User.where(id: responsible_ids)
    if (responsible_ids - [ current_user.id ]).any? && !can_assign_others?(@task.workstream)
      @task.errors.add(:base, "Only the workstream's owners can make someone else responsible")
      return render :new, status: :unprocessable_entity
    end

    recurring = RecurringTask.new(
      title: task_params[:title],
      description: task_params[:description],
      workstream_id: task_params[:workstream_id],
      frequency: @repeats,
      due_wday: params[:task][:due_wday].presence || 0,
      priority: params[:task][:priority],
      effort: task_params[:effort],
      responsibles: User.where(id: responsible_ids),
      created_by: current_user
    )

    if recurring.save
      recurring.instance_for
      notice = "“#{recurring.title}” repeats #{recurring.frequency_label.downcase}. This period's task is ready."
      return close_native_sheet(notice:) if from_native_sheet?
      redirect_to workstream_path(recurring.workstream), notice:
    else
      recurring.errors.each do |error|
        @task.errors.add(:base, "#{RECURRING_ERROR_LABELS.fetch(error.attribute, error.attribute.to_s.humanize)} #{error.message}")
      end
      render :new, status: :unprocessable_entity
    end
  end

  # The apps switch tabs inside a frame, so the screen's URL stays /tasks and
  # pull-to-refresh would otherwise snap back to My Tasks.
  def remembered_tab
    tab_named(session[:tasks_tab]) if hotwire_native_app?
  end

  def tab_named(name)
    TAB_ALIASES.fetch(name.to_s, name).presence_in(TABS)
  end

  def load_my_tab
    # Recurring duties and one-off assignments in one list, soonest due first
    @my_tasks = Task.open.assigned_to(current_user)
      .includes(:workstream, :recurring_task, :released_by, :assignees, task_assignments: :covering_for).reorder(Arel.sql("tasks.due_date IS NULL, tasks.due_date, tasks.created_at"))
    @completed_tasks = Task.completed.where(completed_at: 14.days.ago..)
      .where("tasks.completed_by_id = :id OR tasks.id IN (SELECT task_id FROM task_assignments WHERE user_id = :id)", id: current_user.id)
      .includes(:workstream, :recurring_task).reorder(completed_at: :desc).limit(20)
  end

  def load_available_tab
    @queue = Task.available_queue(current_user).group_by(&:effective_priority)
  end

  # By workstream (what each area covers), every open task in one list, or
  # the recently deleted ones (kept 30 days) to restore
  def load_all_work_tab
    @list = %w[tasks deleted].include?(params[:list]) ? params[:list] : "workstreams"
    case @list
    when "workstreams" then load_coverage_tab
    when "deleted" then @deleted_tasks = Task.only_discarded.includes(:workstream).order(discarded_at: :desc)
    else
      @all_tasks = Task.open.joins(:workstream).merge(Workstream.open)
        .includes(:recurring_task, :assignees, workstream: :owners)
        .reorder(Arel.sql("tasks.due_date IS NULL, tasks.due_date, tasks.created_at"))
      @deleted_count = Task.only_discarded.count
    end
  end

  def load_coverage_tab
    workstreams = Workstream.includes(:owners, recurring_tasks: :responsibles).order(:name)
    @governance = workstreams.open.governance
    @ongoing = workstreams.open.ongoing
    @projects = workstreams.open.projects
    @closed_projects = workstreams.projects.where(status: "closed")
  end

  # A per-period meeting artifact: the current period unless an earlier one
  # is asked for.
  def load_contribution_tab
    today = Time.current.in_time_zone(current_community.time_zone).to_date
    requested = begin
      Date.iso8601(params[:period].to_s)
    rescue Date::Error
      today
    end
    @period = ContributionPeriod.containing([ requested, today ].min, current_community.contribution_period_type)
    @summary = ContributionSummary.new(@period, current_community)
  end

  def set_task
    @task = Task.find(params[:id])
  end

  def set_discarded_task
    @task = Task.with_discarded.find(params[:id])
  end

  # Only a workstream's owner (or an admin) hands work to someone else; anyone
  # can take open work themselves or let go of their own.
  def set_users
    ids = [ current_user.id, *@task&.assignee_ids ]
    @users = can_assign_others? ? User.all : User.where(id: ids)
  end

  def can_assign_others?(workstream = nil)
    return true if current_user.admin?

    workstream ? workstream.owned_by?(current_user) : WorkstreamOwner.exists?(user_id: current_user.id)
  end

  # Owners and admins put anyone on a task; everyone else can only add or
  # take off themselves.
  def assignment_allowed?(task, old_ids, new_ids)
    changed = (old_ids - new_ids) + (new_ids - old_ids)
    return true if changed.empty? || changed.all?(current_user.id)
    return true if task.workstream && can_assign_others?(task.workstream)

    task.errors.add(:assignees, "can only be changed by one of the workstream's owners")
    false
  end

  # A push to each person someone else just put on the task
  def notify_new_assignees(task, user_ids)
    User.where(id: user_ids - [ current_user.id ]).find_each { |user| TaskPush.assigned(task, user, by: current_user) }
  end

  # The people picked on a form (one picker per spot); nil when the form
  # didn't include the pickers.
  def assignee_ids_param
    ids = params.dig(:task, :assignee_ids)
    ids && Array(ids).compact_blank.map(&:to_i).uniq
  end

  # Submitted from one of the apps' form sheets (sheet_form_controller), which
  # the app closes when told to refresh the screen beneath
  def from_native_sheet?
    hotwire_native_app? && params[:sheet].present?
  end

  # The app closes the sheet and refreshes the screen beneath, which shows the
  # notice. (turbo-rails' refresh_or_redirect_to puts it in the URL instead,
  # where nothing reads it.)
  def close_native_sheet(notice:)
    flash[:notice] = notice
    redirect_to turbo_refresh_historical_location_url
  end

  def tasks_path_for(task)
    if task.assigned_to?(current_user) then tasks_path(tab: "my")
    elsif task.assignees.empty? then tasks_path(tab: "available")
    else workstream_path(task.workstream)
    end
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :due_date, :workstream_id, :effort)
  end

  # The page the edit came from (e.g. a workstream), if it's on this site.
  def return_to_path
    url_from(params[:return_to]) || tasks_path
  end
end
