class RoleAssignmentsController < ApplicationController
  before_action :set_role, only: [ :new, :create ]
  before_action :set_assignment, only: [ :destroy ]

  def new
    @assignment = @role.role_assignments.new
    @users = User.all
  end

  def create
    @assignment = @role.role_assignments.new(assignment_params)

    if @assignment.save
      redirect_to role_url(@role), notice: "#{@assignment.user.name} assigned as #{@assignment.assignment_type.humanize}."
    else
      @users = User.all
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    role = @assignment.role
    @assignment.destroy
    redirect_to role_url(role), notice: "Assignment removed."
  end

  private

  def set_role
    @role = Role.find(params[:role_id])
  end

  def set_assignment
    @assignment = RoleAssignment.find(params[:id])
  end

  def assignment_params
    params.require(:role_assignment).permit(:user_id, :assignment_type, :starts_at, :ends_at)
  end
end
