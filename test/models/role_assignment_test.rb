require "test_helper"

class RoleAssignmentTest < ActiveSupport::TestCase
  def setup
    @role = roles(:garden_maven)
    @user = users(:one)
  end

  test "should require role" do
    assignment = RoleAssignment.new(user: @user, assignment_type: "holder", starts_at: Date.current)
    assert_not assignment.valid?
    assert_includes assignment.errors[:role], "must exist"
  end

  test "should require user" do
    assignment = RoleAssignment.new(role: @role, assignment_type: "holder", starts_at: Date.current)
    assert_not assignment.valid?
    assert_includes assignment.errors[:user], "must exist"
  end

  test "should require assignment_type" do
    assignment = RoleAssignment.new(role: @role, user: @user, assignment_type: nil, starts_at: Date.current)
    assert_not assignment.valid?
    assert_includes assignment.errors[:assignment_type], "can't be blank"
  end

  test "should validate assignment_type inclusion" do
    assignment = RoleAssignment.new(role: @role, user: @user, assignment_type: "invalid", starts_at: Date.current)
    assert_not assignment.valid?
    assert_includes assignment.errors[:assignment_type], "is not included in the list"
  end

  test "should require starts_at" do
    assignment = RoleAssignment.new(role: @role, user: @user, assignment_type: "holder", starts_at: nil)
    assert_not assignment.valid?
    assert_includes assignment.errors[:starts_at], "can't be blank"
  end

  test "should allow valid assignment" do
    assignment = RoleAssignment.new(
      role: @role,
      user: @user,
      assignment_type: "holder",
      starts_at: Date.current,
      ends_at: 6.months.from_now.to_date,
      active: true
    )
    assert assignment.valid?
  end

  test "should scope active assignments" do
    active = role_assignments(:maven_holder)
    assert_includes RoleAssignment.active_assignments, active
  end

  test "should scope by assignment type" do
    holder = role_assignments(:maven_holder)
    backup = role_assignments(:maven_backup)
    assert_includes RoleAssignment.holders, holder
    assert_includes RoleAssignment.backups, backup
  end

  test "should detect expiring soon" do
    assignment = role_assignments(:maven_holder)
    assignment.update!(ends_at: 20.days.from_now.to_date)
    assert_includes RoleAssignment.expiring_soon, assignment
  end

  test "should update role vacancy on create" do
    role = roles(:facilitator)
    assert role.vacant?

    RoleAssignment.create!(
      role: role,
      user: @user,
      assignment_type: "holder",
      starts_at: Date.current,
      active: true
    )

    role.reload
    assert_not role.vacant?
  end

  test "should have paper_trail" do
    assignment = role_assignments(:maven_holder)
    assert assignment.respond_to?(:versions)
  end
end
