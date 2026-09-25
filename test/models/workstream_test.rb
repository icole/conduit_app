require "test_helper"

class WorkstreamTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
  end

  test "valid with a name, type and priority" do
    workstream = Workstream.new(name: "Grounds", workstream_type: "permanent", priority: "important", owner: @owner)
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
end
