# frozen_string_literal: true

class MealCalendarSyncJob < ApplicationJob
  queue_as :default

  def perform(meal_id, action: "sync")
    meal = Meal.with_discarded.find_by(id: meal_id)
    return unless meal

    service = MealCalendarSyncService.new(meal)

    case action
    when "sync"
      result = service.sync
      Rails.logger.info "Meal #{meal_id} calendar sync: #{result[:status]}"
    when "delete"
      result = service.delete
      Rails.logger.info "Meal #{meal_id} calendar delete: #{result[:status]}"
    end
  rescue => e
    Rails.logger.error "MealCalendarSyncJob error for meal #{meal_id}: #{e.message}"
  end
end
