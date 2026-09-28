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
      post workstreams_url, params: { workstream: { name: "Vendor Coordinator", description: "Finds contractors", workstream_type: "permanent", priority: "important", owner_ids: [ "", users(:two).id ] } }
    end
    workstream = Workstream.find_by!(name: "Vendor Coordinator")
    assert_equal [ users(:two) ], workstream.owners.to_a
    assert_redirected_to workstream_url(workstream)
  end

  test "members cannot change a workstream's owner" do
    sign_in users(:two)
    patch workstream_url(workstreams(:garbage)), params: { workstream: { owner_ids: [ users(:two).id ] } }
    assert_redirected_to root_url
    assert_equal [ users(:one) ], workstreams(:garbage).reload.owners.to_a
  end

  test "admins update workstreams" do
    sign_in users(:admin_user)
    patch workstream_url(workstreams(:common_house)), params: { workstream: { owner_ids: [ "", users(:three).id, users(:two).id ], priority: "important" } }
    assert_redirected_to workstream_url(workstreams(:common_house))
    assert_equal [ users(:three), users(:two) ].sort_by(&:id), workstreams(:common_house).reload.owners.sort_by(&:id)
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

  test "this period's recurring task can be edited from the workstream page, coming back to it" do
    sign_in users(:one) # owns Garbage & Recycling
    get workstream_url(workstreams(:garbage))
    task = Task.find_by!(recurring_task: recurring_tasks(:garbage_night))
    assert_select "#task_#{task.id} a[href='#{edit_task_path(task, return_to: workstream_path(workstreams(:garbage)))}']", text: "Edit"
  end

  test "other members can't edit someone else's open work from the workstream page" do
    sign_in users(:three)
    get workstream_url(workstreams(:garbage))
    task = Task.find_by!(recurring_task: recurring_tasks(:garbage_night))
    assert_select "#task_#{task.id}"
    assert_select "#task_#{task.id} a", text: "Edit", count: 0
  end

  test "effort shows as a size, not minutes" do
    sign_in users(:admin_user)
    get workstream_url(workstreams(:common_house))
    assert_select "#recurring_task_#{recurring_tasks(:pantry_restock).id} .badge", text: "Medium"
    assert_select ".badge", text: /min/, count: 0
  end

  test "a workstream's owners get Edit and Remove on its recurring tasks; other members don't" do
    recurring = recurring_tasks(:garbage_night)
    sign_in users(:one) # owns Garbage & Recycling
    get workstream_url(workstreams(:garbage))
    assert_select "#recurring_task_#{recurring.id} a[href='#{edit_workstream_recurring_task_path(workstreams(:garbage), recurring)}']", text: "Edit"
    assert_select "#recurring_task_#{recurring.id} button", text: "Remove"

    delete logout_path
    sign_in users(:three)
    get workstream_url(workstreams(:garbage))
    assert_select "#recurring_task_#{recurring.id} a", text: "Edit", count: 0
  end

  test "the workstream page has one Add task, with no separate recurring-task button" do
    sign_in users(:admin_user)
    get workstream_url(workstreams(:common_house))
    assert_select "a[href='#{new_task_path(workstream_id: workstreams(:common_house).id)}']", text: /Add task/
    assert_select "a", text: /Recurring task/, count: 0
  end

  test "the workstream page shows this period's recurring work even before anyone opens Tasks" do
    sign_in users(:one)
    get workstream_url(workstreams(:common_house))
    task = Task.find_by!(recurring_task: recurring_tasks(:pantry_restock))
    assert_select "#task_#{task.id}", text: /Restock common house pantry/
  end

  test "any of a project's owners can close it" do
    workstreams(:front_yard).owners << users(:three)
    sign_in users(:three)
    patch close_workstream_url(workstreams(:front_yard))
    assert workstreams(:front_yard).reload.closed?
  end

  test "admins can clear every owner, which leaves the workstream needing one" do
    sign_in users(:admin_user)
    patch workstream_url(workstreams(:garbage)), params: { workstream: { owner_ids: [ "" ] } }
    assert_empty workstreams(:garbage).reload.owners
    assert_not workstreams(:garbage).covered?
  end

  test "the page lists every owner" do
    workstreams(:front_yard).owners << users(:three)
    sign_in users(:one)
    get workstream_url(workstreams(:front_yard))
    assert_match "Owners:", response.body
    assert_match "Alice Johnson &amp; Mike Davis", response.body
  end

  test "the workstream page keeps the description's paragraphs and list" do
    workstreams(:garbage).update!(description: "Rolls the bins out.\n\nTime commitment: ~15 min/week\n\nAlso, as needed or seasonally:\n• Break down boxes (as needed): Flatten cardboard.")
    sign_in users(:one)
    get workstream_url(workstreams(:garbage))
    assert_select "[data-workstream-description] p", minimum: 3
    assert_select "[data-workstream-description] p", text: /Time commitment: ~15 min\/week/
    assert_select "[data-workstream-description] br"
  end
end
