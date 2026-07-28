require "test_helper"

class GenerateRecurringTasksJobTest < ActiveJob::TestCase
  def setup
    @template = recurring_task_templates(:grounds_walk)
    @holder = role_assignments(:maven_holder)

    # Prevent other templates from generating tasks during tests
    RecurringTaskTemplate.update_all(last_generated_at: Date.current)
  end

  test "should generate task for due template" do
    @template.update!(last_generated_at: 3.weeks.ago.to_date)

    assert_difference("Task.count") do
      GenerateRecurringTasksJob.perform_now
    end

    task = Task.unscoped.order(:created_at).last
    assert_equal @template.title, task.title
    assert_equal @template.role, task.role
    assert_equal @holder.user, task.assigned_to_user
  end

  test "should not generate task for template not yet due" do
    @template.update!(last_generated_at: Date.current)

    assert_no_difference("Task.count") do
      GenerateRecurringTasksJob.perform_now
    end
  end

  test "should not generate task for role with no active holder" do
    @template.update!(last_generated_at: 3.weeks.ago.to_date)
    @holder.update!(active: false)

    assert_no_difference("Task.count") do
      GenerateRecurringTasksJob.perform_now
    end
  end
end
