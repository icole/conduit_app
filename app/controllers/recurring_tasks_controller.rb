# Recurring tasks are set up from the Add task form's "Repeats" choice.
# Admins, the workstream's owners and whoever set one up can change it.
class RecurringTasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workstream
  before_action :set_recurring_task, only: [ :edit, :update, :destroy ]
  before_action :authorize_manager!
  before_action :set_responsible_choices, only: [ :edit, :update ]

  def edit
  end

  def update
    @recurring_task.assign_attributes(recurring_task_params)
    if responsible_allowed? && @recurring_task.save
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

  def authorize_manager!
    return if @recurring_task.manageable_by?(current_user)

    redirect_to root_path, alert: "You are not authorized to access this page."
  end

  # Like assigning a task: only owners and admins pick someone else.
  def can_pick_anyone? = current_user.admin? || @workstream.owned_by?(current_user)

  def set_responsible_choices
    @responsible_choices = can_pick_anyone? ? User.order(:name) : User.where(id: [ current_user.id, @recurring_task.default_responsible_user_id_was ]).order(:name)
  end

  def responsible_allowed?
    return true unless @recurring_task.default_responsible_user_id_changed?
    return true if can_pick_anyone? || @recurring_task.default_responsible_user_id.in?([ nil, current_user.id ])

    @recurring_task.errors.add(:default_responsible_user, "can only be someone else if you own the workstream")
    false
  end

  def recurring_task_params
    params.require(:recurring_task).permit(:title, :description, :frequency, :priority, :effort, :default_responsible_user_id, :starts_on)
  end
end
