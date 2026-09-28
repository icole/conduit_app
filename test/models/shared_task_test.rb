require "test_helper"

# Tasks that need more than one person, like meeting facilitation.
class SharedTaskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @one, @two, @three = users(:one), users(:two), users(:three)
  end

  def shared_task(people: [ @one, @two ], needed: 2, workstream: workstreams(:general))
    Task.create!(title: "Facilitate the meeting", user: @one, workstream: workstream, people_needed: needed, assignees: people)
  end

  test "a task can need two people and have both on it" do
    task = shared_task
    assert_equal [ @one, @two ].sort_by(&:name), task.assignees.to_a
    assert_equal 0, task.open_spots
    assert task.assigned_to?(@one)
    assert_not task.assigned_to?(@three)
    assert_not_includes Task.available, task
    assert_includes Task.assigned_to(@two), task
  end

  test "with a spot open it's in the Available queue for everyone not already on it" do
    task = shared_task(people: [ @one ])
    assert_equal 1, task.open_spots
    assert_includes Task.available, task
    assert_includes Task.available_queue(@three), task
    assert_not_includes Task.available_queue(@one), task
  end

  test "claiming takes the open spot; a full task can't be claimed, nor claimed twice by the same person" do
    task = shared_task(people: [ @one ])
    assert_not task.claim!(@one)
    assert task.claim!(@three)
    assert_equal [ @one, @three ].sort_by(&:name), task.reload.assignees.to_a
    assert_not task.claim!(users(:four))
  end

  test "releasing takes only your spot, and whoever claims it is covering for you" do
    task = shared_task
    perform_enqueued_jobs(only: []) { assert task.release!(@one) }
    task.reload
    assert_equal [ @two ], task.assignees.to_a
    assert_equal [ @one, 1 ], [ task.released_by, task.open_spots ]

    task.claim!(@three)
    assert_equal @one, task.task_assignments.find_by!(user: @three).covering_for
    assert_nil task.task_assignments.find_by!(user: @two).covering_for
  end

  test "you can only release a task you're on" do
    task = shared_task
    assert_not task.release!(@three)
    assert_equal 2, task.reload.assignees.size
  end

  test "a governance task both holders are on can't be released: nobody else could take the spot" do
    task = shared_task(people: [ @two, @three ], workstream: workstreams(:facilitators)) # held by two and three
    assert_not task.releasable?
    assert_not task.release!(@two)
  end

  test "people needed is at least one" do
    task = Task.new(title: "T", user: @one, workstream: workstreams(:general), people_needed: 0)
    assert_not task.valid?
    assert task.errors[:people_needed].any?
  end

  test "can't have more people on it than it needs" do
    task = Task.new(title: "T", user: @one, workstream: workstreams(:general), people_needed: 1, assignees: [ @one, @two ])
    assert_not task.valid?
    assert task.errors[:assignees].any?
  end

  test "assigned_to_user is shorthand for just one person" do
    task = Task.create!(title: "Solo", user: @one, workstream: workstreams(:general), assigned_to_user: @two)
    assert_equal [ @two ], task.assignees.to_a
    assert_equal @two, task.assigned_to_user

    task.update!(assigned_to_user: nil)
    assert_empty task.reload.assignees
  end

  test "a recurring task can have two people responsible, and each period's task goes to both" do
    recurring = RecurringTask.create!(workstream: workstreams(:facilitators), title: "Facilitate the monthly meeting", frequency: "monthly",
                                      estimated_minutes: 90, created_by: users(:admin_user), people_needed: 2, responsibles: [ @two, @three ])
    assert recurring.covered?

    task = recurring.instance_for.reload
    assert_equal [ 2, [ @two, @three ].sort_by(&:name) ], [ task.people_needed, task.assignees.to_a ]
  end

  test "a recurring task with fewer people than it needs isn't covered" do
    recurring = RecurringTask.create!(workstream: workstreams(:facilitators), title: "Facilitate", frequency: "monthly",
                                      estimated_minutes: 90, created_by: users(:admin_user), people_needed: 2, responsibles: [ @two ])
    assert_not recurring.covered?
    assert_equal 1, recurring.instance_for.open_spots
  end

  test "each person on a finished shared task gets its full time toward contribution" do
    @one.update!(household: households(:smith_household))
    @two.update!(household: households(:jones_household))
    Task.where(status: "completed").update_all(completed_at: Time.zone.local(2025, 1, 1))
    task = shared_task
    task.update!(estimated_minutes: 90, status: "completed")
    task.update_columns(completed_at: Time.zone.local(2026, 2, 10))

    summary = ContributionSummary.new(ContributionPeriod.containing(Date.new(2026, 3, 1), "semi_annual"))
    assert_equal 90, summary.minutes_for(households(:smith_household))
    assert_equal 90, summary.minutes_for(households(:jones_household))
  end

  test "deleting an account also clears assignments on its deleted tasks" do
    member = User.create!(name: "Leaving Member", email: "leaving@example.com", password: "password123!", community: communities(:crow_woods))
    task = Task.create!(title: "Old job", user: member, workstream: workstreams(:general), assignees: [ @two ])
    task.discard

    assert_difference("TaskAssignment.count", -1) { member.destroy! }
    assert_not Task.unscoped.exists?(task.id)
  end
end
