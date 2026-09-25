require "test_helper"

class WorkstreamsControllerTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  test "index sends members to the Coverage tab" do
    sign_in users(:one)
    get workstreams_url
    assert_redirected_to tasks_url(tab: "coverage")
  end

  test "any member can view a workstream" do
    sign_in users(:one)
    get workstream_url(workstreams(:garbage))
    assert_response :success
    assert_match "Garbage &amp; Recycling Coordinator", response.body
    assert_match "Take out garbage", response.body
  end

  test "members cannot create workstreams" do
    sign_in users(:one)
    get new_workstream_url
    assert_redirected_to root_url

    assert_no_difference("Workstream.count") do
      post workstreams_url, params: { workstream: { name: "Sprawl", workstream_type: "permanent", priority: "important" } }
    end
  end

  test "admins create workstreams and assign owners" do
    sign_in users(:admin_user)
    get new_workstream_url
    assert_response :success

    assert_difference("Workstream.count") do
      post workstreams_url, params: { workstream: { name: "Vendor Coordinator", description: "Finds contractors", workstream_type: "permanent", priority: "important", owner_id: users(:two).id } }
    end
    workstream = Workstream.order(:created_at).last
    assert_equal users(:two), workstream.owner
    assert_redirected_to workstream_url(workstream)
  end

  test "members cannot change a workstream's owner" do
    sign_in users(:two)
    patch workstream_url(workstreams(:garbage)), params: { workstream: { owner_id: users(:two).id } }
    assert_redirected_to root_url
    assert_equal users(:one), workstreams(:garbage).reload.owner
  end

  test "admins update workstreams" do
    sign_in users(:admin_user)
    patch workstream_url(workstreams(:common_house)), params: { workstream: { owner_id: users(:three).id, priority: "important" } }
    assert_redirected_to workstream_url(workstreams(:common_house))
    assert_equal users(:three), workstreams(:common_house).reload.owner
  end

  test "the owner can close a one-time project" do
    sign_in users(:two)
    patch close_workstream_url(workstreams(:front_yard))
    assert workstreams(:front_yard).reload.closed?
  end

  test "other members cannot close a project" do
    sign_in users(:one)
    patch close_workstream_url(workstreams(:front_yard))
    assert_not workstreams(:front_yard).reload.closed?
  end

  test "workstreams from another community are not reachable" do
    sign_in users(:one)
    get workstream_url(ActsAsTenant.without_tenant { workstreams(:other_general) })
    assert_response :not_found
  end

  test "owners and admins can delete open work from the workstream page" do
    task = Task.create!(title: "Paint the shed", user: users(:two), workstream: workstreams(:garbage))

    sign_in users(:one) # owns Garbage & Recycling
    get workstream_url(workstreams(:garbage))
    assert_select "#task_#{task.id} form[action='#{task_path(task)}'] input[name='_method'][value='delete']"
  end

  test "other members don't get a delete button on someone else's open work" do
    task = Task.create!(title: "Paint the shed", user: users(:two), workstream: workstreams(:garbage))

    sign_in users(:three)
    get workstream_url(workstreams(:garbage))
    assert_select "#task_#{task.id}"
    assert_select "#task_#{task.id} form[action='#{task_path(task)}']", count: 0
  end
end
