require "test_helper"

class RecurringTasksControllerTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  setup do
    @workstream = workstreams(:common_house)
  end

  test "members cannot edit recurring tasks" do
    sign_in users(:one)
    patch workstream_recurring_task_url(@workstream, recurring_tasks(:pantry_restock)), params: { recurring_task: { title: "Mine now" } }
    assert_redirected_to root_url
    assert_equal "Restock common house pantry", recurring_tasks(:pantry_restock).reload.title
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
