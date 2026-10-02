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
    old_ids = @recurring_task.responsible_ids
    new_ids = responsible_ids_param || old_ids
    @recurring_task.assign_attributes(recurring_task_params)

    saved = responsible_allowed?(old_ids, new_ids) && RecurringTask.transaction do
      @recurring_task.responsibles = User.where(id: new_ids) unless new_ids.sort == old_ids.sort
      @recurring_task.save || raise(ActiveRecord::Rollback)
      follow_in_open_instances(old_ids)
      true
    end

    if saved
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
    @responsible_choices = can_pick_anyone? ? User.order(:name) : User.where(id: [ current_user.id, *@recurring_task.responsible_ids ]).order(:name)
  end

  def responsible_allowed?(old_ids, new_ids)
    changed = (old_ids - new_ids) + (new_ids - old_ids)
    return true if changed.empty? || changed.all?(current_user.id) || can_pick_anyone?

    @recurring_task.errors.add(:responsibles, "can only be someone else if you own the workstream")
    false
  end

  def responsible_ids_param
    ids = params.dig(:recurring_task, :responsible_ids)
    ids && Array(ids).compact_blank.map(&:to_i).uniq
  end

  # This period's task takes the new people, unless someone already changed
  # who's on it (a release, a claim, a reassignment).
  def follow_in_open_instances(old_ids)
    @recurring_task.instances.open.includes(:assignees).find_each do |task|
      next if task.released_by_id || task.assignee_ids.sort != old_ids.sort

      task.update!(assignees: @recurring_task.responsibles.to_a)
    end
  end

  def recurring_task_params
    params.require(:recurring_task).permit(:title, :description, :frequency, :priority, :effort, :starts_on, :due_wday)
  end
end
