require "test_helper"

class WorkstreamTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
  end

  test "valid with a name, type and priority" do
    workstream = Workstream.new(name: "Grounds", workstream_type: "permanent", priority: "important", owners: [ @owner ])
    assert workstream.valid?
  end

  test "requires a name" do
    workstream = Workstream.new(workstream_type: "permanent", priority: "important")
    assert_not workstream.valid?
    assert_includes workstream.errors[:name], "can't be blank"
  end

  test "type must be permanent or ad_hoc" do
    workstream = Workstream.new(name: "X", workstream_type: "role", priority: "important")
    assert_not workstream.valid?
    assert workstream.errors[:workstream_type].any?
  end

  test "priority must be one of the three levels" do
    %w[essential important nice_to_have].each do |level|
      assert Workstream.new(name: "X #{level}", workstream_type: "permanent", priority: level).valid?, level
    end
    assert_not Workstream.new(name: "X", workstream_type: "permanent", priority: "urgent").valid?
  end

  test "labels types in the community's vocabulary" do
    assert_equal "Ongoing Operations", workstreams(:garbage).type_label
    assert_equal "One-Time Project", workstreams(:front_yard).type_label
  end

  test "owner is optional, and a workstream without one needs an owner" do
    assert workstreams(:garbage).covered?
    assert_not workstreams(:common_house).covered?
  end

  test "close! closes a workstream" do
    workstream = workstreams(:front_yard)
    workstream.close!
    assert workstream.reload.closed?
    assert_not_includes Workstream.open, workstream
  end

  test "priority_rank orders essential before important before nice to have" do
    ranks = %w[essential important nice_to_have].map { |p| Workstream.priority_rank(p) }
    assert_equal ranks.sort, ranks
  end

  test "a workstream can have several owners, and each of them owns it" do
    workstream = workstreams(:front_yard)
    workstream.owners << users(:three)

    assert_equal [ users(:three), users(:two) ].sort_by(&:name), workstream.owners.sort_by(&:name)
    assert workstream.owned_by?(users(:two))
    assert workstream.owned_by?(users(:three))
    assert_not workstream.owned_by?(users(:one))
    assert workstream.covered?
  end

  test "owner_names reads naturally for one or several owners" do
    assert_equal "Jane Smith", workstreams(:garbage).owner_names
    workstreams(:garbage).owners << users(:two)
    assert_equal "Jane Smith & Mike Davis", workstreams(:garbage).reload.owner_names
  end

  test "a person owns a workstream only once" do
    assert_raises(ActiveRecord::RecordInvalid) { WorkstreamOwner.create!(workstream: workstreams(:garbage), user: users(:one)) }
  end

  test "governance roles are their own type, always required" do
    role = Workstream.create!(name: "HOA Secretary", workstream_type: "governance", priority: "nice_to_have")
    assert_equal "Governance", role.type_label
    assert role.governance?
    assert_equal "essential", role.priority, "a required role is essential, whatever was asked"
    assert_includes Workstream.governance, role
    assert_not_includes Workstream.ongoing, role
  end
end
