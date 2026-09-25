require "test_helper"

class ContributionSummaryTest < ActiveSupport::TestCase
  setup do
    @smith = households(:smith_household)
    @jones = households(:jones_household)
    users(:one).update!(household: @smith)
    users(:two).update!(household: @jones)
    @period = ContributionPeriod.containing(Date.new(2026, 3, 1), "semi_annual")
    Task.where(status: "completed").update_all(completed_at: Time.zone.local(2025, 1, 1))
  end

  def complete(title, by:, minutes:, on: Time.zone.local(2026, 2, 10), workstream: workstreams(:general), due: nil)
    Task.create!(title: title, user: by, workstream: workstream, estimated_minutes: minutes, due_date: due,
                 status: "completed", completed_by: by, completed_at: on)
  end

  test "sums completed effort by household and derives a fair share" do
    complete "Mow", by: users(:one), minutes: 90
    complete "Sweep", by: users(:one), minutes: 30
    complete "Bins", by: users(:two), minutes: 60
    complete "Outside the period", by: users(:two), minutes: 600, on: Time.zone.local(2026, 7, 2)

    summary = ContributionSummary.new(@period)
    assert_equal 120, summary.minutes_for(@smith)
    assert_equal 60, summary.minutes_for(@jones)
    assert_equal 180, summary.total_minutes
    assert_equal 90, summary.fair_share_minutes
  end

  test "lists households with members alphabetically, never ranked by contribution" do
    complete "Lots", by: users(:two), minutes: 500
    names = ContributionSummary.new(@period).households.map(&:name)
    assert_equal [ "Jones Unit", "The Smith Family" ], names
    assert_not_includes names, "Vacant Unit"
  end

  test "work by members without a household is counted separately" do
    complete "Solo", by: users(:three), minutes: 45
    summary = ContributionSummary.new(@period)
    assert_equal 45, summary.unaffiliated_minutes
    assert_equal 0, summary.total_minutes
  end

  test "essential coverage is the share of essential work due so far that got done" do
    garbage = workstreams(:garbage)
    complete "Done on time", by: users(:one), minutes: 15, workstream: garbage, due: Date.new(2026, 2, 8)
    Task.create!(title: "Missed", user: users(:one), workstream: garbage, due_date: Date.new(2026, 2, 15))
    Task.create!(title: "Not important enough", user: users(:one), workstream: workstreams(:general), due_date: Date.new(2026, 2, 15))

    travel_to Date.new(2026, 3, 1) do
      assert_equal 50, ContributionSummary.new(@period).essential_coverage_percent
    end
  end

  test "essential coverage is unknown before anything essential is due" do
    travel_to Date.new(2026, 1, 1) do
      assert_nil ContributionSummary.new(@period).essential_coverage_percent
    end
  end

  test "areas needing help are essential workstreams and recurring tasks nobody holds" do
    RecurringTask.create!(workstream: workstreams(:garbage), title: "Scrub the bins", frequency: "monthly",
                          priority: "essential", estimated_minutes: 30, created_by: users(:admin_user))
    areas = ContributionSummary.new(@period).areas_needing_help
    assert_includes areas, [ workstreams(:common_house).name, "No owner assigned" ]
    assert_includes areas, [ "Scrub the bins", "Nobody responsible · #{workstreams(:garbage).name}" ]
    assert_not areas.any? { |name, _| name == "Restock common house pantry" }, "important work isn't flagged"
  end

  test "recently completed lists the period's completed work, newest first" do
    complete "Older", by: users(:one), minutes: 15, on: Time.zone.local(2026, 1, 10)
    complete "Newer", by: users(:two), minutes: 45, on: Time.zone.local(2026, 3, 10)
    assert_equal [ "Newer", "Older" ], ContributionSummary.new(@period).recently_completed.map(&:title)
  end
end
