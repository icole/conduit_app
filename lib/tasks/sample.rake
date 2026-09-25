# frozen_string_literal: true

namespace :sample do
  desc "Load the task management prototype's workstreams, tasks and sample neighbours. " \
       "SLUG=<community slug> (optional when there's only one), VIEWER=<email> gets the sample My Tasks"
  task tasks: :environment do
    community = ActsAsTenant.without_tenant do
      if ENV["SLUG"].present?
        Community.find_by!(slug: ENV["SLUG"])
      elsif Community.count == 1
        Community.first
      else
        abort "Several communities here; pick one with SLUG=#{Community.pluck(:slug).join('|')}"
      end
    end

    viewer = ENV["VIEWER"].presence && ActsAsTenant.with_tenant(community) { User.find_by!(email: ENV["VIEWER"]) }
    TaskSampleData.new(community, viewer: viewer).load!

    ActsAsTenant.with_tenant(community) do
      puts "Loaded sample task data into #{community.name}: #{Workstream.count} workstreams, " \
           "#{RecurringTask.count} recurring tasks, #{Task.count} tasks, #{Household.count} households."
    end
  rescue TaskSampleData::Refused => e
    abort e.message
  end
end
