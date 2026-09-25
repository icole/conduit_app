class WorkstreamsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!, only: [ :new, :create, :edit, :update ]
  before_action :set_workstream, only: [ :show, :edit, :update, :close, :reopen ]
  before_action :authorize_owner_or_admin!, only: [ :close, :reopen ]

  # The list of workstreams lives on the Tasks page's Coverage tab.
  def index
    redirect_to tasks_path(tab: "coverage")
  end

  def show
    @recurring_tasks = @workstream.recurring_tasks.includes(:default_responsible_user).order(:title)
    @open_tasks = @workstream.tasks.open.includes(:assigned_to_user, :released_by, :recurring_task).order(:due_date, :created_at)
    @users = User.order(:name)
  end

  def new
    @workstream = Workstream.new(workstream_type: params[:type].presence_in(Workstream::TYPES.keys) || "permanent")
  end

  def create
    @workstream = Workstream.new(workstream_params)

    if @workstream.save
      redirect_to @workstream, notice: "Workstream created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @workstream.update(workstream_params)
      redirect_to @workstream, notice: "Workstream updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def close
    @workstream.close!
    redirect_to @workstream, notice: "#{@workstream.name} closed."
  end

  def reopen
    @workstream.reopen!
    redirect_to @workstream, notice: "#{@workstream.name} reopened."
  end

  private

  def set_workstream
    @workstream = Workstream.find(params[:id])
  end

  def authorize_owner_or_admin!
    return if current_user.admin? || @workstream.owned_by?(current_user)

    redirect_to @workstream, alert: "Only the owner or an admin can do that."
  end

  def workstream_params
    params.require(:workstream).permit(:name, :description, :workstream_type, :priority, :owner_id)
  end
end
