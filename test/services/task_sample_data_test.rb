require "test_helper"
require "minitest/mock"

class TaskSampleDataTest < ActiveSupport::TestCase
  setup do
    @community = communities(:crow_woods)
    @viewer = users(:one)
    # The fixture pantry task has nobody responsible; start from the prototype's.
    recurring_tasks(:pantry_restock).discard
  end

  def load!
    travel_to(Date.new(2026, 3, 4)) { TaskSampleData.new(@community, viewer: @viewer).load! }
  end

  test "creates the workstreams from the prototype, grouped by type" do
    load!
    names = Workstream.ongoing.pluck(:name)
    [ "Garbage & Recycling Coordinator", "Garden Health", "Garden People Wrangler", "Groundskeeper",
      "Common House Wrangler", "Community Meal Supporter", "Amenities (Hot Tub, Fire Pit, Fountain)",
      "Vendor Coordinator", "Crow Woods Ambassador" ].each { |name| assert_includes names, name }
    assert_equal [ "Front yard project", "High water bills" ], Workstream.projects.where(name: [ "Front yard project", "High water bills" ]).order(:name).pluck(:name)
    assert_empty Workstream.find_by(name: "Common House Wrangler").owners
    assert_empty Workstream.find_by(name: "Crow Woods Ambassador").owners
    assert_equal "Priya Goldberg", Workstream.find_by(name: "Garden Health").owner_names
  end

  test "gives the viewer the prototype's My Tasks" do
    load!
    travel_to(Date.new(2026, 3, 4)) do
      mine = Task.open.where(assigned_to_user: @viewer).pluck(:title)
      assert_includes mine, "Take out garbage & recycling"
      assert_includes mine, "Restock common house pantry"
      assert_includes mine, "Buy supplies for work party"
      assert_includes mine, "Draft quarterly budget note"
    end
  end

  test "leaves released and uncovered work in the Available queue" do
    load!
    queue = Task.available_queue
    greenhouse = queue.find { |t| t.title == "Water the greenhouse" }
    assert_equal "Dana Okafor", greenhouse.released_by.name
    assert_equal "essential", queue.first.effective_priority
    assert queue.any? { |t| t.title == "Clean shared kitchen" }
    assert queue.any? { |t| t.title == "Organize the tool shed" }
  end

  test "builds completed history across five households" do
    load!
    summary = ContributionSummary.new(ContributionPeriod.containing(Date.new(2026, 3, 4), "semi_annual"), @community)
    sample = summary.households.select { |h| %w[Rivera-Chen Okafor Nguyen-Park Goldberg Santos].include?(h.name) }
    assert_equal 5, sample.size
    assert sample.all? { |h| summary.minutes_for(h).positive? }
    assert summary.recently_completed.any?
  end

  test "is safe to run twice" do
    load!
    counts = [ Workstream.count, RecurringTask.count, Task.count, User.count, Household.count ]
    load!
    assert_equal counts, [ Workstream.count, RecurringTask.count, Task.count, User.count, Household.count ]
  end

  test "won't add sample people to a real community in production" do
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_raises(TaskSampleData::Refused) { TaskSampleData.new(@community, viewer: @viewer).load! }
    end
  end

  test "without people it loads only the structure, with nobody owning or holding anything" do
    counts = [ User.count, Household.count ]
    travel_to(Date.new(2026, 3, 4)) { TaskSampleData.new(@community, people: false).load! }

    assert_equal counts, [ User.count, Household.count ]
    sample = Workstream.where(name: [ "Garden Health", "Groundskeeper", "High water bills" ])
    assert_equal 3, sample.count
    assert sample.all? { |w| w.owners.empty? }
    assert RecurringTask.where(title: [ "Mow common lawn", "Water the greenhouse" ]).all? { |r| r.default_responsible_user.nil? }
    assert_nil Task.find_by!(title: "Buy supplies for work party").assigned_to_user
    assert_not Task.completed.where(recurring_task: RecurringTask.where(title: "Mow common lawn")).exists?
    travel_to(Date.new(2026, 3, 4)) do
      assert Task.available_queue.any? { |t| t.title == "Mow common lawn" }
    end
  end

  test "without people it's allowed in a real community in production" do
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_nothing_raised { TaskSampleData.new(@community, people: false).load! }
    end
  end
end
