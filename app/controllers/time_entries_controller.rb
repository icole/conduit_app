# frozen_string_literal: true

class TimeEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_role, only: [ :new, :create ]

  def index
    @time_entries = TimeEntry.for_user(current_user).recent.limit(50)
    @monthly_by_role = TimeEntry.for_user(current_user)
      .for_month(Date.current.year, Date.current.month)
      .group(:role_id)
      .sum(:hours)
    @roles = Role.where(id: @monthly_by_role.keys)
  end

  def new
    @time_entry = TimeEntry.new(role: @role, logged_on: Date.current, entry_type: "reconciliation")
    @tasks = @role.tasks.where(status: %w[active backlog])
  end

  def create
    @time_entry = TimeEntry.new(time_entry_params)
    @time_entry.user = current_user
    @time_entry.role = @role

    if @time_entry.save
      redirect_to role_url(@role), notice: "Time logged: #{@time_entry.hours} hours."
    else
      @tasks = @role.tasks.where(status: %w[active backlog])
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @time_entry = TimeEntry.find(params[:id])
    @time_entry.destroy
    redirect_to time_entries_url, notice: "Time entry removed."
  end

  private

  def set_role
    @role = Role.find(params[:role_id])
  end

  def time_entry_params
    params.require(:time_entry).permit(:hours, :logged_on, :entry_type, :task_id, :note)
  end
end
