require "test_helper"

class RecurringTasksControllerTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  setup do
    @workstream = workstreams(:common_house)
  end

  test "members cannot add recurring tasks" do
    sign_in users(:one)
    assert_no_difference("RecurringTask.count") do
      post workstream_recurring_tasks_url(@workstream), params: { recurring_task: { title: "Sweep", frequency: "weekly", estimated_minutes: 20 } }
    end
    assert_redirected_to root_url
  end

  test "admins add recurring tasks with a default responsible person" do
    sign_in users(:admin_user)
    get new_workstream_recurring_task_url(@workstream)
    assert_response :success

    assert_difference("RecurringTask.count") do
      post workstream_recurring_tasks_url(@workstream), params: { recurring_task: {
        title: "Clean shared kitchen", frequency: "weekly", estimated_minutes: 45,
        priority: "essential", default_responsible_user_id: users(:two).id
      } }
    end
    recurring = RecurringTask.order(:created_at).last
    assert_equal @workstream, recurring.workstream
    assert_equal users(:two), recurring.default_responsible_user
    assert_equal users(:admin_user), recurring.created_by
    assert_redirected_to workstream_url(@workstream)
  end

  test "admins edit and remove recurring tasks" do
    sign_in users(:admin_user)
    recurring = recurring_tasks(:pantry_restock)

    patch workstream_recurring_task_url(@workstream, recurring), params: { recurring_task: { default_responsible_user_id: users(:one).id } }
    assert_redirected_to workstream_url(@workstream)
    assert_equal users(:one), recurring.reload.default_responsible_user

    delete workstream_recurring_task_url(@workstream, recurring)
    assert recurring.reload.discarded?
  end
end
