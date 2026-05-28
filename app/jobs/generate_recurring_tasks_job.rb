class GenerateRecurringTasksJob < ApplicationJob
  queue_as :default

  def perform
    RecurringTaskTemplate.find_each do |template|
      next unless template.due_for_generation?

      holder = template.role.current_holders.first
      next unless holder

      template.generate_task!(holder.user)
    end
  end
end
