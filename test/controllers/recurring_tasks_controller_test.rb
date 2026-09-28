require "test_helper"

class RecurringTasksControllerTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  setup do
    @workstream = workstreams(:common_house)
  end

  test "a workstream's owners edit and remove its recurring tasks" do
    sign_in users(:one) # owns Garbage & Recycling
    recurring = recurring_tasks(:garbage_night)
    patch workstream_recurring_task_url(workstreams(:garbage), recurring), params: { recurring_task: { title: "Bins out" } }
    assert_redirected_to workstream_url(workstreams(:garbage))
    assert_equal "Bins out", recurring.reload.title

    delete workstream_recurring_task_url(workstreams(:garbage), recurring)
    assert recurring.reload.discarded?
  end

  test "whoever set up a repeating task can change it, but only owners make someone else responsible" do
    recurring = RecurringTask.create!(workstream: @workstream, title: "Water the plants", frequency: "weekly", estimated_minutes: 15,
                                      created_by: users(:three), default_responsible_user: users(:three))
    sign_in users(:three) # doesn't own Common House

    patch workstream_recurring_task_url(@workstream, recurring), params: { recurring_task: { title: "Water the houseplants" } }
    assert_redirected_to workstream_url(@workstream)
    assert_equal "Water the houseplants", recurring.reload.title

    patch workstream_recurring_task_url(@workstream, recurring), params: { recurring_task: { default_responsible_user_id: users(:two).id } }
    assert_response :unprocessable_entity
    assert_equal users(:three), recurring.reload.default_responsible_user
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

  test "the recurring task form sizes effort as Small, Medium or Large instead of minutes" do
    sign_in users(:admin_user)
    recurring = recurring_tasks(:pantry_restock) # 40 min: Medium

    get edit_workstream_recurring_task_url(@workstream, recurring)
    assert_select "select[name='recurring_task[effort]'] option[selected]", text: "Medium"
    assert_select "[name='recurring_task[estimated_minutes]']", count: 0

    patch workstream_recurring_task_url(@workstream, recurring), params: { recurring_task: { effort: "Medium", title: "Restock the pantry" } }
    assert_equal 40, recurring.reload.estimated_minutes

    patch workstream_recurring_task_url(@workstream, recurring), params: { recurring_task: { effort: "Large" } }
    assert_equal 90, recurring.reload.estimated_minutes
  end
end
