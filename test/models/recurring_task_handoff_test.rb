require "test_helper"

# Someone can't keep doing a recurring job at all (not just this time): they
# hand it off, and it waits in Available until someone takes it on.
class RecurringTaskHandoffTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @recurring = recurring_tasks(:garbage_night) # Jane's, weekly
    @jane = users(:one)
    @mike = users(:two)
    @this_week = @recurring.instance_for
  end

  test "handing off takes you off it for good and this period's task goes to the queue" do
    assert @recurring.hand_off!(@jane)

    assert_empty @recurring.reload.responsibles
    assert @recurring.looking_for_someone?
    assert_equal @jane, @recurring.handed_off_by
    assert_includes Task.available, @this_week.reload
    assert_equal @jane, @this_week.released_by
    assert_includes RecurringTask.looking_for_someone, @recurring
  end

  test "handing off announces it once, in chat and by push, and not the period's task separately" do
    assert_enqueued_jobs(1, only: HandoffBroadcastJob) do
      assert_no_enqueued_jobs(only: CoverageBroadcastJob) { @recurring.hand_off!(@jane) }
    end
  end

  test "a job shared with someone else stays with them, with nothing to announce" do
    @recurring.update!(responsibles: [ @jane, @mike ])
    @this_week.update!(assignees: [ @jane, @mike ])

    assert_no_enqueued_jobs(only: HandoffBroadcastJob) { assert @recurring.hand_off!(@jane) }
    assert_equal [ @mike ], @recurring.reload.responsibles
    assert_not @recurring.looking_for_someone?
    assert_equal [ @mike ], @this_week.reload.assignees
  end

  test "only someone responsible for it can hand it off" do
    assert_not @recurring.hand_off_allowed?(@mike)
    assert_not @recurring.hand_off!(@mike)
    assert_equal [ @jane ], @recurring.reload.responsibles
  end

  test "a governance role held by one person can't be handed off" do
    role = RecurringTask.create!(title: "Build the agenda", workstream: workstreams(:facilitators), estimated_minutes: 60,
      created_by: @jane, responsibles: [ @mike ])
    assert_not role.hand_off_allowed?(@mike)
    assert_not role.hand_off!(@mike)
  end

  test "open work nobody was ever responsible for isn't looking for someone" do
    assert_not recurring_tasks(:pantry_restock).looking_for_someone?
    assert_not_includes RecurringTask.looking_for_someone, recurring_tasks(:pantry_restock)
  end

  test "taking it on makes it yours from now on, including this period's task" do
    @recurring.hand_off!(@jane)

    assert @recurring.take_on!(@mike)
    assert_equal [ @mike ], @recurring.reload.responsibles
    assert_not @recurring.looking_for_someone?
    assert_nil @recurring.handed_off_at
    assert_equal [ @mike ], @this_week.reload.assignees
  end

  test "taking it on leaves this period's task with whoever already picked it up" do
    @recurring.hand_off!(@jane)
    @this_week.reload.claim!(users(:three))

    assert @recurring.take_on!(@mike)
    assert_equal [ users(:three) ], @this_week.reload.assignees
  end

  test "only one person can take it on" do
    @recurring.hand_off!(@jane)
    assert @recurring.take_on!(@mike)
    assert_not @recurring.take_on!(users(:three))
    assert_equal [ @mike ], @recurring.reload.responsibles
  end

  test "an owner putting someone on it also settles the handoff" do
    @recurring.hand_off!(@jane)
    @recurring.update!(responsibles: [ @mike ])
    assert_nil @recurring.reload.handed_off_at
  end

  test "the job leaving the community's list settles it too" do
    @recurring.hand_off!(@jane)
    @recurring.discard
    assert_not_includes RecurringTask.looking_for_someone, @recurring
  end

  test "a member who handed something off can still be removed from the community" do
    leaving = User.create!(name: "Sam Leaving", email: "sam@example.com", password: "password123")
    @recurring.update!(responsibles: [ leaving ])
    @recurring.hand_off!(leaving)
    @recurring.discard
    leaving.destroy!
    assert_nil RecurringTask.with_discarded.find(@recurring.id).handed_off_by_id
  end
end
