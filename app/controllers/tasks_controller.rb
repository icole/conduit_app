class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [ :edit, :update, :destroy, :prioritize, :move_to_backlog, :reorder ]
  before_action :set_discarded_task, only: [ :restore ]

  def index
    @current_view = params[:view] || "active"

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

    @task = Task.new
    @users = User.all

    # Separate tasks by status for the view (also apply assignment filter)
    @backlog_tasks = base_query.backlog.limit(10)
    @active_tasks = base_query.prioritized
    @completed_tasks = base_query.completed.limit(10)
    @deleted_count = Task.only_discarded.count
  end

  def new
    @task = Task.new
  end

  def create
    @task = current_user.tasks.build(task_params)

    respond_to do |format|
      if @task.save
        redirect_path = if request.referer&.include?("tasks")
          tasks_path(view: @task.status == "active" ? "active" : "backlog")
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

    if @task.update(task_params)
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
    redirect_path = request.referer&.include?("tasks") ? tasks_path : dashboard_index_path
    redirect_to redirect_path, notice: "Task restored."
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
    rescue => e
      Rails.logger.error "Error in reorder: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { success: false, error: e.message }, status: 500
    end
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def set_discarded_task
    @task = Task.with_discarded.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :assigned_to_user_id, :due_date)
  end

  def reorder_pending_tasks
    pending_tasks = Task.pending.order(:priority_order)
    pending_tasks.each_with_index do |task, index|
      task.update_column(:priority_order, index + 1) if task.priority_order != index + 1
    end
  end
end
