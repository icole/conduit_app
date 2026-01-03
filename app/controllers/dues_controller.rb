# frozen_string_literal: true

class DuesController < ApplicationController
  before_action :authorize_admin!

  def index
    @year = params[:year]&.to_i || Date.current.year
    @households = Household.includes(:household_dues_payments).order(:name)
    @months = (1..12).to_a

    # Build a hash for quick lookup: { household_id => { month => paid } }
    @payment_status = build_payment_status_hash(@year)
  end

  def toggle
    @household = Household.find(params[:household_id])
    @year = params[:year].to_i
    @month = params[:month].to_i

    payment = @household.dues_payment_for(year: @year, month: @month)
    payment.paid = !payment.paid
    payment.save!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to dues_path(year: @year) }
    end
  end

  def settings
    @community = current_community
  end

  def update_settings
    if current_community.update(community_params)
      redirect_to dues_settings_path, notice: "Dues settings updated successfully."
    else
      @community = current_community
      render :settings, status: :unprocessable_entity
    end
  end

  private

  def build_payment_status_hash(year)
    payments = HouseholdDuesPayment.joins(:household)
      .where(households: { community_id: current_community.id })
      .where(year: year)
      .pluck(:household_id, :month, :paid)

    payments.each_with_object({}) do |(household_id, month, paid), hash|
      hash[household_id] ||= {}
      hash[household_id][month] = paid
    end
  end

  def community_params
    params.require(:community).permit(:monthly_dues_amount)
  end
end
