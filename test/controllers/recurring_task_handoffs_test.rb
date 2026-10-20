require "test_helper"

# Handing a recurring job off for good from My Tasks, and taking it on from
# Available.
class RecurringTaskHandoffsTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  setup do
    @recurring = recurring_tasks(:garbage_night) # Jane's
    @workstream = @recurring.workstream
    @hand_off = hand_off_workstream_recurring_task_path(@workstream, @recurring)
    @take_on = take_on_workstream_recurring_task_path(@workstream, @recurring)
  end

  test "your recurring job on My Tasks can be handed off for good" do
    sign_in users(:one)
    get tasks_url(tab: "my")
    assert_select "form[action='#{@hand_off}'] button", text: "Hand it off for good"
  end

  test "a job you're covering this time, not responsible for, can't be handed off" do
    task = @recurring.instance_for
    task.release!(users(:one))
    task.claim!(users(:two))
    sign_in users(:two)
    get tasks_url(tab: "my")
    assert_select "##{ActionView::RecordIdentifier.dom_id(task)}"
    assert_select "form[action='#{@hand_off}']", count: 0
  end

  test "handing it off takes you off it and asks the community" do
    sign_in users(:one)
    assert_enqueued_jobs(1, only: HandoffBroadcastJob) { patch @hand_off }
    assert_redirected_to tasks_url(tab: "my")
    assert_equal "Handed off. We've asked who can take it on.", flash[:notice]
    assert @recurring.reload.looking_for_someone?
  end

  test "you can't hand off someone else's job" do
    sign_in users(:two)
    patch @hand_off
    assert_redirected_to tasks_url(tab: "my")
    assert_equal [ users(:one) ], @recurring.reload.responsibles
  end

  test "Available asks someone to take on a handed-off job" do
    @recurring.hand_off!(users(:one))
    sign_in users(:two)
    get tasks_url(tab: "available")
    assert_select "#needs-someone-new" do
      assert_select "[id='#{ActionView::RecordIdentifier.dom_id(@recurring)}']", text: /Take out garbage & recycling/
      assert_select "[id='#{ActionView::RecordIdentifier.dom_id(@recurring)}']", text: /Handed off by Jane/
      assert_select "form[action='#{@take_on}'] button", text: "Take it on"
    end
    assert_select "#needs-someone-new", text: /Restock common house pantry/, count: 0
  end

  test "this period's task sits on the handed-off job's card, not again in the queue below" do
    task = @recurring.instance_for
    @recurring.hand_off!(users(:one))
    sign_in users(:two)
    get tasks_url(tab: "available")
    assert_select "[data-priority-group] ##{ActionView::RecordIdentifier.dom_id(task)}", count: 0
    assert_select "#needs-someone-new form[action^='#{claim_task_path(task)}'] button", text: "Just this once"
  end

  test "no section when nothing's been handed off" do
    sign_in users(:two)
    get tasks_url(tab: "available")
    assert_select "#needs-someone-new", count: 0
  end

  test "taking it on makes it yours" do
    @recurring.hand_off!(users(:one))
    sign_in users(:two)
    patch @take_on
    assert_redirected_to tasks_url(tab: "available")
    assert_equal "“Take out garbage & recycling” is yours from now on. Find it under My Tasks.", flash[:notice]
    assert_equal [ users(:two) ], @recurring.reload.responsibles
  end

  test "someone else got there first" do
    @recurring.hand_off!(users(:one))
    @recurring.take_on!(users(:three))
    sign_in users(:two)
    patch @take_on
    assert_redirected_to tasks_url(tab: "available")
    assert_equal "Someone already took that one on.", flash[:alert]
    assert_equal [ users(:three) ], @recurring.reload.responsibles
  end
end
