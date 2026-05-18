require "test_helper"

class RoleTest < ActiveSupport::TestCase
  def setup
    @community = communities(:crow_woods)
  end

  test "should require title" do
    role = Role.new(title: nil, role_type: "role")
    assert_not role.valid?
    assert_includes role.errors[:title], "can't be blank"
  end

  test "should require role_type" do
    role = Role.new(title: "Test Role", role_type: nil)
    assert_not role.valid?
    assert_includes role.errors[:role_type], "can't be blank"
  end

  test "should validate role_type inclusion" do
    role = Role.new(title: "Test Role", role_type: "invalid")
    assert_not role.valid?
    assert_includes role.errors[:role_type], "is not included in the list"
  end

  test "should validate group inclusion" do
    role = Role.new(title: "Test Role", role_type: "role", group: "invalid")
    assert_not role.valid?
    assert_includes role.errors[:group], "is not included in the list"
  end

  test "should allow valid role" do
    role = Role.new(
      title: "Compost Coordinator",
      role_type: "role",
      group: "garden",
      term_length_months: 6,
      duties: "Maintain landscaping health"
    )
    assert role.valid?
  end

  test "should default vacant to true" do
    role = Role.new(title: "Test", role_type: "role")
    assert role.vacant?
  end

  test "should scope by role_type" do
    assert Role.roles.all? { |r| r.role_type == "role" }
    assert Role.committees.all? { |r| r.role_type == "committee" }
  end

  test "should scope by group" do
    assert Role.in_group("hoa_officers").all? { |r| r.group == "hoa_officers" }
  end

  test "should have paper_trail" do
    role = roles(:garden_maven)
    assert role.respond_to?(:versions)
  end
end
