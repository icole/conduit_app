class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [ :edit, :update, :destroy ]

  def index
    @tasks = if params[:status].present?
      Task.where(status: params[:status])
    else
      Task.all
    end
             
    # Filter by assignment if requested
    if params[:assigned_to].present?
      if params[:assigned_to] == 'unassigned'
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
    @redirect_path = request.referer&.include?("tasks") ? tasks_path : dashboard_index_path

    respond_to do |format|
      if @task.update(task_params)
        format.html { redirect_to @redirect_path, notice: "Task was successfully updated." }
        format.turbo_stream
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@task, "form"), partial: "tasks/form", locals: { task: @task }) }
      end
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
    @task = current_user.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :assigned_to_user_id)
  end
end
