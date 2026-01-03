# frozen_string_literal: true

class HouseholdsController < ApplicationController
  before_action :authorize_admin!
  before_action :set_household, only: [ :edit, :update, :destroy ]

  def index
    @households = Household.includes(:users).order(:name)
  end

  def new
    @household = Household.new
  end

  def create
    @household = Household.new(household_params)

    if @household.save
      redirect_to households_path, notice: "Household was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @household.update(household_params)
      update_household_members
      redirect_to households_path, notice: "Household was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @household.destroy
    redirect_to households_path, notice: "Household was successfully deleted."
  end

  private

  def set_household
    @household = Household.find(params[:id])
  end

  def household_params
    params.require(:household).permit(:name)
  end

  def update_household_members
    return unless params[:household][:user_ids]

    submitted_user_ids = params[:household][:user_ids].reject(&:blank?).map(&:to_i)

    # Remove users who were unchecked
    @household.users.where.not(id: submitted_user_ids).update_all(household_id: nil)

    # Add users who were checked
    User.where(id: submitted_user_ids).update_all(household_id: @household.id)
  end
end
