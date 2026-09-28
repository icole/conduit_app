require "test_helper"

# Tasks several people share, like meeting facilitation.
class SharedTaskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @one, @two, @three = users(:one), users(:two), users(:three)
  end

  def shared_task(people: [ @one, @two ], workstream: workstreams(:general))
    Task.create!(title: "Facilitate the meeting", user: @one, workstream: workstream, assignees: people)
  end

  test "a task can have several people on it" do
    task = shared_task
    assert_equal [ @one, @two ].sort_by(&:name), task.assignees.to_a
    assert task.assigned_to?(@one)
    assert_not task.assigned_to?(@three)
    assert_includes Task.assigned_to(@two), task
  end

  test "only tasks nobody is on are in the Available queue" do
    shared = shared_task
    nobody = Task.create!(title: "Unclaimed", user: @one, workstream: workstreams(:general))
    assert_not_includes Task.available, shared
    assert_includes Task.available, nobody
  end

  test "leaving a shared task keeps it with the others, off the queue and out of chat" do
    task = shared_task
    assert_no_enqueued_jobs(only: CoverageBroadcastJob) { assert task.release!(@one) }
    task.reload
    assert_equal [ @two ], task.assignees.to_a
    assert_nil task.released_by
    assert_not_includes Task.available, task
  end

  test "the last person releasing it sends it to the queue, and whoever claims it covers for them" do
    task = shared_task(people: [ @one ])
    assert_enqueued_jobs(1, only: CoverageBroadcastJob) { assert task.release!(@one) }
    assert_equal @one, task.reload.released_by
    assert_includes Task.available, task

    assert task.claim!(@three)
    assert_equal [ @three ], task.reload.assignees.to_a
    assert_equal @one, task.task_assignments.find_by!(user: @three).covering_for
    assert_not task.claim!(@two), "someone's on it now"
  end

  test "you can only release a task you're on" do
    task = shared_task
    assert_not task.release!(@three)
    assert_equal 2, task.reload.assignees.size
  end

  test "a governance task shared by two holders can be left by one; a single holder can't hand it off" do
    shared = shared_task(people: [ @two, @three ], workstream: workstreams(:facilitators)) # held by two and three
    assert shared.release!(@two)
    assert_equal [ @three ], shared.reload.assignees.to_a

    alone = shared_task(people: [ @one ], workstream: workstreams(:treasurer)) # held by one alone
    assert_not alone.releasable?
  end

  test "assigned_to_user is shorthand for just one person" do
    task = Task.create!(title: "Solo", user: @one, workstream: workstreams(:general), assigned_to_user: @two)
    assert_equal [ @two ], task.assignees.to_a
    assert_equal @two, task.assigned_to_user

    task.update!(assigned_to_user: nil)
    assert_empty task.reload.assignees
  end

  test "a recurring task can have several people, and each period's task goes to all of them" do
    recurring = RecurringTask.create!(workstream: workstreams(:facilitators), title: "Facilitate the monthly meeting", frequency: "monthly",
                                      estimated_minutes: 90, created_by: users(:admin_user), responsibles: [ @two, @three ])
    assert recurring.covered?
    assert_equal [ @two, @three ].sort_by(&:name), recurring.instance_for.reload.assignees.to_a
  end

  test "a recurring task with nobody responsible isn't covered" do
    recurring = RecurringTask.create!(workstream: workstreams(:facilitators), title: "Facilitate", frequency: "monthly",
                                      estimated_minutes: 90, created_by: users(:admin_user))
    assert_not recurring.covered?
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

  test "the one-person and headcount columns are gone; people live only in the join tables" do
    task_columns = ActiveRecord::Base.connection.columns(:tasks).map(&:name)
    recurring_columns = ActiveRecord::Base.connection.columns(:recurring_tasks).map(&:name)
    assert_empty task_columns & %w[assigned_to_user_id people_needed]
    assert_empty recurring_columns & %w[default_responsible_user_id people_needed]
  end
end
