class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [ :edit, :update, :destroy ]

  def index
    @tasks = if params[:status].present?
      Task.where(status: params[:status])
    else
      # Default to showing only pending tasks
      Task.where(status: "pending")
    end

    # Filter by assignment if requested
    if params[:assigned_to].present?
      if params[:assigned_to] == "unassigned"
        @tasks = @tasks.where(assigned_to_user_id: nil)
      else
        @tasks = @tasks.where(assigned_to_user_id: params[:assigned_to])
      end
    end

    @task = Task.new
    @users = User.all
  end

  def new
    @task = Task.new
  end

  def create
    @task = current_user.tasks.build(task_params)
    @redirect_path = request.referer&.include?("tasks") ? tasks_path : dashboard_index_path


    respond_to do |format|
      if @task.save
        format.html { redirect_to @redirect_path, notice: "Task was successfully created." }
        format.turbo_stream
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
    @task.destroy
    @redirect_path = request.referer&.include?("tasks") ? tasks_path : dashboard_index_path

    respond_to do |format|
      format.html { redirect_to @redirect_path, notice: "Task was successfully deleted." }
      format.turbo_stream
    end
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :assigned_to_user_id)
  end
end
