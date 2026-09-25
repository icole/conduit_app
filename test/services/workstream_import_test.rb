require "test_helper"

class WorkstreamImportTest < ActiveSupport::TestCase
  setup do
    @community = communities(:crow_woods)
    # Jane Smith (one), Mike Davis (two), Alice Johnson (three)
    @data = {
      "rename_workstreams" => { "Front yard project" => "Front yard & signs" },
      "rename_recurring_tasks" => { "Restock common house pantry" => "Monitor & restock supplies" },
      "remove_recurring_tasks" => [ "Take out garbage & recycling" ],
      "remove_unstarted_tasks" => [ "Complete Project Documentation" ],
      "workstreams" => [
        { "name" => "Common House Wrangler", "type" => "permanent", "priority" => "important",
          "description" => "Keeps the Common House clean.", "owners" => [ "Mike" ], "time_commitment" => "~4-6 hrs/month",
          "recurring_tasks" => [
            { "title" => "Monitor & restock supplies", "description" => "Restock sponges and soap.", "frequency" => "monthly", "minutes" => 20 },
            { "title" => "Deep clean", "description" => "Thorough deep-clean.", "frequency" => "quarterly", "minutes" => 150 }
          ],
          "also" => [ "Launder linens (as needed): Wash the linens." ] },
        { "name" => "Front yard & signs", "type" => "ad_hoc", "priority" => "important",
          "description" => "Bench and signs.", "owners" => [ "Mike", "Alice" ] },
        { "name" => "Garden Health", "type" => "permanent", "priority" => "important",
          "description" => "Keeps the landscaping healthy.", "owners" => [ "Jane" ],
          "recurring_tasks" => [
            { "title" => "Winterize spigots", "description" => "Drain the spigots.", "frequency" => "yearly", "minutes" => 90, "first_period_starts" => "11-01" }
          ] }
      ]
    }
  end

  def import(data = @data, dry_run: false)
    travel_to(Date.new(2026, 9, 25)) { WorkstreamImport.new(@community, data).apply!(dry_run: dry_run) }
  end

  test "updates existing workstreams and creates missing ones" do
    import
    common = Workstream.find_by!(name: "Common House Wrangler")
    assert_equal "important", common.priority
    assert_equal [ users(:two) ], common.owners.to_a
    assert_includes common.description, "Keeps the Common House clean."
    assert_includes common.description, "Time commitment: ~4-6 hrs/month"
    assert_includes common.description, "Launder linens (as needed): Wash the linens."

    garden = Workstream.find_by!(name: "Garden Health")
    assert_equal [ "permanent", [ users(:one) ] ], [ garden.workstream_type, garden.owners.to_a ]
  end

  test "renames first, so a renamed workstream keeps its history and gets every owner" do
    front_yard = workstreams(:front_yard)
    import
    assert_equal "Front yard & signs", front_yard.reload.name
    assert_equal [ users(:three), users(:two) ], front_yard.owners.to_a
  end

  test "creates and updates recurring tasks, with the first owner responsible" do
    pantry = recurring_tasks(:pantry_restock)
    import
    pantry.reload
    assert_equal [ "Monitor & restock supplies", "monthly", 20, users(:two) ],
                 [ pantry.title, pantry.frequency, pantry.estimated_minutes, pantry.default_responsible_user ]

    deep_clean = RecurringTask.find_by!(title: "Deep clean")
    assert_equal [ "quarterly", 150, users(:two) ], [ deep_clean.frequency, deep_clean.estimated_minutes, deep_clean.default_responsible_user ]
  end

  test "yearly tasks start on the given date so they fall due in season" do
    import
    winterize = RecurringTask.find_by!(title: "Winterize spigots")
    assert_equal Date.new(2025, 11, 1), winterize.starts_on
    assert_equal Date.new(2026, 10, 31), winterize.period_for(Date.new(2026, 9, 25)).end
  end

  test "this period's open instance follows the update" do
    instance = travel_to(Date.new(2026, 9, 25)) { recurring_tasks(:pantry_restock).instance_for }
    import
    instance.reload
    assert_equal [ "Monitor & restock supplies", 20, users(:two) ], [ instance.title, instance.estimated_minutes, instance.assigned_to_user ]
  end

  test "removes the listed recurring tasks and only unstarted one-off tasks" do
    started = Task.create!(title: "Complete Project Documentation", user: users(:one), workstream: workstreams(:general), assigned_to_user: users(:one))
    unstarted = tasks(:one) # same title, unassigned
    import
    assert recurring_tasks(:garbage_night).reload.discarded?
    assert unstarted.reload.discarded?
    assert_not started.reload.discarded?
  end

  test "a dry run reports the changes and writes nothing" do
    report = import(dry_run: true)
    assert report.any? { |line| line.include?("create workstream Garden Health") }
    assert report.any? { |line| line.include?("remove recurring task Take out garbage & recycling") }
    assert_nil Workstream.find_by(name: "Garden Health")
    assert_not recurring_tasks(:garbage_night).reload.discarded?
  end

  test "running it again changes nothing" do
    import
    assert_empty import
  end

  test "an owner name that matches nobody, or more than one person, stops the import before any change" do
    data = @data.deep_dup
    data["workstreams"][2]["owners"] = [ "Nobody" ]
    error = assert_raises(WorkstreamImport::Error) { import(data) }
    assert_match "Nobody", error.message
    assert_nil Workstream.find_by(name: "Garden Health")

    data["workstreams"][2]["owners"] = [ "Email" ] # Email User, Email User Two, ...
    assert_raises(WorkstreamImport::Error) { import(data) }
  end
end
