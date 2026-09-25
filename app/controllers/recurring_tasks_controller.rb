# Recurring tasks are pre-loaded by admins; members never set them up.
class RecurringTasksController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_workstream
  before_action :set_recurring_task, only: [ :edit, :update, :destroy ]

  def new
    @recurring_task = @workstream.recurring_tasks.build(frequency: "weekly", estimated_minutes: 30)
  end

  def create
    @recurring_task = @workstream.recurring_tasks.build(recurring_task_params.merge(created_by: current_user))

    if @recurring_task.save
      redirect_to @workstream, notice: "Recurring task added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @recurring_task.update(recurring_task_params)
      redirect_to @workstream, notice: "Recurring task updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recurring_task.discard
    redirect_to @workstream, notice: "Recurring task removed."
  end

  private

  def set_workstream
    @workstream = Workstream.find(params[:workstream_id])
  end

  def set_recurring_task
    @recurring_task = @workstream.recurring_tasks.find(params[:id])
  end

  def recurring_task_params
    params.require(:recurring_task).permit(:title, :description, :frequency, :priority, :estimated_minutes, :default_responsible_user_id, :starts_on)
  end
end
