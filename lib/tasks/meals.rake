# frozen_string_literal: true

namespace :meals do
  desc "Sync all upcoming meals to Google Calendar"
  task sync_to_calendar: :environment do
    Community.find_each do |community|
      ActsAsTenant.with_tenant(community) do
        meals = Meal.upcoming.where(google_event_id: nil)
        total = meals.count

        next if total.zero?

        puts "Syncing #{total} upcoming meals for #{community.name}..."

        meals.find_each.with_index do |meal, index|
          print "  [#{index + 1}/#{total}] #{meal.title}..."
          result = MealCalendarSyncService.new(meal).sync

          if result[:status] == :success
            puts " done"
          else
            puts " #{result[:status]}: #{result[:error] || result[:reason]}"
          end
        end
      end
    end

    puts "Complete!"
  end

  desc "Sync ALL meals (including past) to Google Calendar"
  task sync_all_to_calendar: :environment do
    Community.find_each do |community|
      ActsAsTenant.with_tenant(community) do
        meals = Meal.where(google_event_id: nil)
        total = meals.count

        next if total.zero?

        puts "Syncing #{total} meals for #{community.name}..."

        meals.find_each.with_index do |meal, index|
          print "  [#{index + 1}/#{total}] #{meal.title}..."
          result = MealCalendarSyncService.new(meal).sync

          if result[:status] == :success
            puts " done"
          else
            puts " #{result[:status]}: #{result[:error] || result[:reason]}"
          end
        end
      end
    end

    puts "Complete!"
  end
end
