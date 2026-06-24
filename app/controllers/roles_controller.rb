class RolesController < ApplicationController
  before_action :set_role, only: [ :show, :edit, :update, :destroy ]

  def index
    @roles_by_group = Role.includes(:role_assignments, :users).group_by(&:group)
  end

  def show
    @assignments = @role.role_assignments.active_assignments.includes(:user)
    @tasks = @role.tasks.limit(20)
    @time_entries = @role.time_entries.recent.limit(10)
    @templates = @role.recurring_task_templates
  end

  def new
    @role = Role.new
  end

  def create
    @role = Role.new(role_params)

    if @role.save
      redirect_to role_url(@role), notice: "Role was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @role.update(role_params)
      redirect_to role_url(@role), notice: "Role was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @role.discard
    redirect_to roles_url, notice: "Role was deleted."
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def role_params
    params.require(:role).permit(:title, :duties, :description, :group, :role_type, :term_length_months)
  end
end
