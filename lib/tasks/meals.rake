# frozen_string_literal: true

namespace :meals do
  desc "Sync all upcoming meals to Google Calendar"
  task sync_to_calendar: :environment do
    meals = Meal.upcoming.where(google_event_id: nil)
    total = meals.count

    puts "Syncing #{total} upcoming meals to Google Calendar..."

    meals.find_each.with_index do |meal, index|
      print "\r  [#{index + 1}/#{total}] Syncing: #{meal.title}..."
      result = MealCalendarSyncService.new(meal).sync

      if result[:status] == :success
        print " done"
      else
        print " #{result[:status]}: #{result[:error] || result[:reason]}"
      end
    end

    puts "\nComplete!"
  end

  desc "Sync ALL meals (including past) to Google Calendar"
  task sync_all_to_calendar: :environment do
    meals = Meal.where(google_event_id: nil)
    total = meals.count

    puts "Syncing #{total} meals to Google Calendar..."

    meals.find_each.with_index do |meal, index|
      print "\r  [#{index + 1}/#{total}] Syncing: #{meal.title}..."
      result = MealCalendarSyncService.new(meal).sync

      if result[:status] == :success
        print " done"
      else
        print " #{result[:status]}: #{result[:error] || result[:reason]}"
      end
    end

    puts "\nComplete!"
  end
end
