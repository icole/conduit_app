class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [ :edit, :update, :destroy, :prioritize, :move_to_backlog, :reorder, :release, :claim ]
  before_action :set_discarded_task, only: [ :restore ]
  before_action :set_users, only: [ :index, :new, :edit, :create, :update ]

  TAB_LABELS = { "my" => "My Tasks", "available" => "Available", "coverage" => "Coverage", "contribution" => "Contribution" }.freeze
  TABS = TAB_LABELS.keys.freeze

  def index
    @task = Task.new

    # The backlog / priority board, reached from My Tasks
    if params[:view].present?
      @tab = "my"
      load_board
    else
      @tab = params[:tab].presence_in(TABS) || remembered_tab || "my"
      session[:tasks_tab] = @tab if hotwire_native_app?
      RecurringTask.generate_instances!(Time.current.in_time_zone(current_community.time_zone).to_date)
      case @tab
      when "available" then load_available_tab
      when "coverage" then load_coverage_tab
      when "contribution" then load_contribution_tab
      else load_my_tab
      end
    end
  end

  def new
    @task = Task.new(workstream_id: params[:workstream_id])
  end

  def create
    return create_recurring if params.dig(:task, :repeats).present?

    @task = current_user.tasks.build(task_params)

    respond_to do |format|
      if assignment_allowed?(@task) && @task.save
        redirect_path = if request.referer&.include?("tasks")
          tasks_path_for(@task)
        else
          dashboard_index_path
        end
        format.html { redirect_to redirect_path, notice: "Task was successfully created." }
        format.turbo_stream { flash.now[:notice] = "Task was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("new_task", partial: "tasks/form", locals: { task: @task }) }
      end
    end
  end

  def edit
  end

  def update
    # Get the return_to path from params or default to tasks_path
    return_to = params[:return_to] || tasks_path

    @task.assign_attributes(task_params)

    if assignment_allowed?(@task) && @task.save
      # Explicitly redirect to the return_to path
      redirect_to return_to, notice: "Task was successfully updated."
    else
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

  def release
    if @task.release!(current_user)
      redirect_to tasks_path(tab: "my"), notice: "Released to the queue. We let the community know in chat."
    else
      redirect_to tasks_path(tab: "my"), alert: "Only the person it's assigned to can release a task."
    end
  end

  def claim
    if !@task.claimable_by?(current_user)
      redirect_to tasks_path(tab: "available"), alert: "That's for the #{@task.workstream.name} to pick up."
    elsif @task.claim!(current_user)
      redirect_to tasks_path(tab: "available"), notice: "It's yours. Find it under My Tasks."
    else
      redirect_to tasks_path(tab: "available"), alert: "Someone already picked that one up."
    end
  end

  def prioritize
    @task.prioritize!

    respond_to do |format|
      format.html { redirect_to tasks_path, notice: "Task moved to active list." }
      format.turbo_stream { flash.now[:notice] = "Task moved to active list." }
    end
  end

  def move_to_backlog
    @task.move_to_backlog!

    respond_to do |format|
      format.html { redirect_to tasks_path, notice: "Task moved to backlog." }
      format.turbo_stream { flash.now[:notice] = "Task moved to backlog." }
    end
  end

  def reorder
    begin
      new_order = params[:priority_order].to_i

      if new_order <= 0
        render json: { success: false, error: "Invalid order" }
        return
      end

      # Get all active tasks ordered by priority, excluding current task
      all_tasks = Task.active.order(:priority_order).to_a

      # Create new ordered list
      other_tasks = all_tasks.reject { |t| t.id == @task.id }

      # Insert the current task at the new position
      # Convert to 0-based index and ensure it's within bounds
      insert_index = [ (new_order - 1), other_tasks.length ].min
      insert_index = [ insert_index, 0 ].max

      new_task_order = other_tasks.dup
      new_task_order.insert(insert_index, @task)

      # Update all priorities based on new positions
      new_task_order.each_with_index do |task, index|
        new_priority = index + 1
        if task.priority_order != new_priority
          task.update_column(:priority_order, new_priority)
        end
      end

      @task.reload
      render json: { success: true, new_order: @task.priority_order }
    rescue StandardError => e
      Rails.logger.error "Error in reorder: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { success: false, error: e.message }, status: 500
    end
  end

  private

  RECURRING_ERROR_LABELS = { estimated_minutes: "Estimated effort", frequency: "Repeats", workstream: "Workstream", title: "Title" }.freeze

  # "Repeats" on the Add task form sets up a recurring task instead. Only
  # admins pre-load recurring work; members add one-off tasks.
  def create_recurring
    @task = current_user.tasks.build(task_params)
    @repeats = params[:task][:repeats]

    unless current_user.admin?
      @task.errors.add(:base, "Only admins can set up repeating tasks")
      return render :new, status: :unprocessable_entity
    end

    recurring = RecurringTask.new(
      title: task_params[:title],
      description: task_params[:description],
      workstream_id: task_params[:workstream_id],
      frequency: @repeats,
      priority: params[:task][:priority],
      estimated_minutes: task_params[:estimated_minutes],
      default_responsible_user_id: task_params[:assigned_to_user_id].presence,
      created_by: current_user
    )

    if recurring.save
      recurring.instance_for
      redirect_to workstream_path(recurring.workstream),
                  notice: "“#{recurring.title}” repeats #{recurring.frequency_label.downcase}. This period's task is ready."
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
    session[:tasks_tab].presence_in(TABS) if hotwire_native_app?
  end

  def load_my_tab
    mine = Task.open.where(assigned_to_user: current_user)
      .includes(:workstream, :recurring_task, :released_by).reorder(Arel.sql("tasks.due_date IS NULL, tasks.due_date, tasks.created_at"))
    # Recurring responsibilities are the instances you're the default person
    # for; an instance you picked up for someone else is just assigned to you.
    @recurring_tasks, @assigned_tasks = mine.partition { |task| task.recurring_task&.default_responsible_user_id == current_user.id }
  end

  def load_available_tab
    @queue = Task.available_queue(current_user).group_by(&:effective_priority)
  end

  def load_coverage_tab
    workstreams = Workstream.includes(:owners, :recurring_tasks).order(:name)
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

  def load_board
    @current_view = params[:view]

    # Build base query with assignment filter
    base_query = Task.all
    if params[:assigned_to].present?
      if params[:assigned_to] == "unassigned"
        base_query = base_query.where(assigned_to_user_id: nil)
      else
        base_query = base_query.where(assigned_to_user_id: params[:assigned_to])
      end
    end

    @tasks = case @current_view
    when "backlog"
      base_query.backlog
    when "active"
      base_query.prioritized
    when "completed"
      base_query.completed
    when "overdue"
      base_query.overdue
    when "due_soon"
      base_query.due_soon
    when "deleted"
      Task.only_discarded.order(discarded_at: :desc)
    else
      base_query.active
    end

    # Separate tasks by status for the view (also apply assignment filter)
    @backlog_tasks = base_query.backlog.limit(10)
    @active_tasks = base_query.prioritized
    @completed_tasks = base_query.completed.limit(10)
    @deleted_count = Task.only_discarded.count
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
    ids = [ current_user.id, @task&.assigned_to_user_id ].compact
    @users = can_assign_others? ? User.all : User.where(id: ids)
  end

  def can_assign_others?(workstream = nil)
    return true if current_user.admin?

    workstream ? workstream.owned_by?(current_user) : WorkstreamOwner.exists?(user_id: current_user.id)
  end

  def assignment_allowed?(task)
    return true unless task.assigned_to_user_id_changed?
    return true if task.workstream && can_assign_others?(task.workstream)

    was, now = task.assigned_to_user_id_was, task.assigned_to_user_id
    return true if was.nil? && now == current_user.id
    return true if was == current_user.id && now.nil?

    task.errors.add(:assigned_to_user, "can only be changed by one of the workstream's owners")
    false
  end

  def tasks_path_for(task)
    case task.assigned_to_user_id
    when current_user.id then tasks_path(tab: "my")
    when nil then tasks_path(tab: "available")
    else workstream_path(task.workstream)
    end
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :assigned_to_user_id, :due_date, :workstream_id, :estimated_minutes)
  end

  def reorder_pending_tasks
    pending_tasks = Task.pending.order(:priority_order)
    pending_tasks.each_with_index do |task, index|
      task.update_column(:priority_order, index + 1) if task.priority_order != index + 1
    end
  end
end
