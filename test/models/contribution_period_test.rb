require "test_helper"

class ContributionPeriodTest < ActiveSupport::TestCase
  test "semi-annual periods are January to June and July to December" do
    period = ContributionPeriod.containing(Date.new(2026, 3, 5), "semi_annual")
    assert_equal Date.new(2026, 1, 1)..Date.new(2026, 6, 30), period.range
    assert_equal "Jan – Jun 2026", period.label
    assert_equal Date.new(2025, 7, 1), period.previous.start_date
    assert_equal Date.new(2026, 7, 1), period.next.start_date
  end

  test "quarterly periods are calendar quarters" do
    period = ContributionPeriod.containing(Date.new(2026, 8, 20), "quarterly")
    assert_equal Date.new(2026, 7, 1)..Date.new(2026, 9, 30), period.range
    assert_equal "Jul – Sep 2026", period.label
  end

  test "knows whether it is the current period" do
    assert ContributionPeriod.containing(Date.current, "quarterly").current?
    assert_not ContributionPeriod.containing(Date.current - 1.year, "quarterly").current?
  end

  test "the community picks the period type, semi-annual by default" do
    community = communities(:crow_woods)
    assert_equal "semi_annual", community.contribution_period_type
    community.contribution_period_type = "quarterly"
    assert_equal "quarterly", community.contribution_period_type
    community.contribution_period_type = "yearly"
    assert_equal "semi_annual", community.contribution_period_type
  end
end
