require "test_helper"

class RecurringTaskTemplateTest < ActiveSupport::TestCase
  def setup
    @role = roles(:garden_maven)
  end

  test "should require role" do
    template = RecurringTaskTemplate.new(title: "Test", frequency: "weekly")
    assert_not template.valid?
    assert_includes template.errors[:role], "must exist"
  end

  test "should require title" do
    template = RecurringTaskTemplate.new(role: @role, frequency: "weekly")
    assert_not template.valid?
    assert_includes template.errors[:title], "can't be blank"
  end

  test "should require frequency" do
    template = RecurringTaskTemplate.new(role: @role, title: "Test")
    assert_not template.valid?
    assert_includes template.errors[:frequency], "can't be blank"
  end

  test "should validate frequency inclusion" do
    template = RecurringTaskTemplate.new(role: @role, title: "Test", frequency: "hourly")
    assert_not template.valid?
    assert_includes template.errors[:frequency], "is not included in the list"
  end

  test "should allow valid template" do
    template = RecurringTaskTemplate.new(
      role: @role,
      title: "Grounds walk",
      description: "Walk the grounds to observe and respond to landscaping needs",
      frequency: "biweekly",
      auto_assign_to_holder: true
    )
    assert template.valid?
  end

  test "should generate a task" do
    template = recurring_task_templates(:grounds_walk)
    user = users(:one)

    task = template.generate_task!(user)

    assert task.persisted?
    assert_equal template.title, task.title
    assert_equal template.description, task.description
    # TODO: assert_equal template.role, task.role — Task doesn't have role_id yet (Task 5)
    assert_equal user, task.assigned_to_user
  end

  test "due_for_generation returns true when never generated" do
    template = RecurringTaskTemplate.new(role: @role, title: "Test", frequency: "weekly", last_generated_at: nil)
    assert template.due_for_generation?
  end

  test "due_for_generation returns false when recently generated" do
    template = RecurringTaskTemplate.new(role: @role, title: "Test", frequency: "weekly", last_generated_at: Date.current)
    assert_not template.due_for_generation?
  end
end
