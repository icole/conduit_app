require "test_helper"

# Tasks several people share, through the pages people use.
class SharedTasksTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    delete logout_path
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  setup do
    @one, @two, @three = users(:one), users(:two), users(:three)
    sign_in @one # owns Garbage & Recycling
  end

  def shared_task(people: [ @one, @two ], workstream: workstreams(:garbage))
    Task.create!(title: "Facilitate the meeting", user: @one, workstream: workstream, assignees: people)
  end

  test "an owner can put several people on a new task" do
    post tasks_url, params: { task: { title: "Deep clean the bins", workstream_id: workstreams(:garbage).id,
                                      assignee_ids: [ "", @one.id, @two.id ] } }
    assert_equal [ @one, @two ].sort_by(&:name), Task.find_by!(title: "Deep clean the bins").assignees.to_a
  end

  test "a member who doesn't own the workstream can only put themselves on it" do
    sign_in @three
    assert_no_difference("Task.count") do
      post tasks_url, params: { task: { title: "Sweep", workstream_id: workstreams(:general).id, assignee_ids: [ @three.id, @two.id ] } }
    end
    assert_response :unprocessable_entity
  end

  test "people are picked in a dropdown that shows who's chosen, with no People needed" do
    task = shared_task
    get edit_task_url(task)
    assert_select "details.dropdown summary", text: /Jane Smith, Mike Davis/
    assert_select "details.dropdown input[type=checkbox]", minimum: 3
    assert_select "input[type=checkbox][name='task[assignee_ids][]'][value='#{@one.id}'][checked]"
    assert_select "input[type=checkbox][name='task[assignee_ids][]'][value='#{@two.id}'][checked]"
    assert_select "input[type=checkbox][name='task[assignee_ids][]'][value='#{@three.id}']:not([checked])"
    assert_select "input[type=hidden][name='task[assignee_ids][]'][value='']" # so unticking everyone clears it
    assert_select "[name='task[people_needed]']", count: 0
  end

  test "unticking everyone takes everyone off" do
    task = shared_task
    patch task_url(task), params: { task: { assignee_ids: [ "" ] } }
    assert_empty task.reload.assignees
  end

  test "My Tasks shows who you share a task with, and whose spot you're covering" do
    shared_task
    covered = shared_task(people: [ @three ])
    covered.release!(@three)
    covered.claim!(@one)

    get tasks_url(tab: "my")
    assert_select "#my-work", text: /With Mike/
    assert_select "#task_#{covered.id}", text: /Covering for Alice/
  end

  test "leaving a shared task keeps it with the others and out of Available" do
    task = shared_task
    patch release_task_url(task)
    assert_equal [ @two ], task.reload.assignees.to_a

    get tasks_url(tab: "available")
    assert_select "#task_#{task.id}", count: 0
  end

  test "the workstream page lists everyone on a task, and Assign puts someone on one nobody has" do
    shared = shared_task
    nobody = Task.create!(title: "Wash the bins", user: @one, workstream: workstreams(:garbage))
    get workstream_url(workstreams(:garbage))
    assert_select "#task_#{shared.id}", text: /Jane Smith and Mike Davis/
    assert_select "#task_#{shared.id} select[name='task[assignee_ids][]']", count: 0
    assert_select "#task_#{nobody.id} select[name='task[assignee_ids][]']"

    patch task_url(nobody, return_to: workstream_path(workstreams(:garbage))), params: { task: { assignee_ids: [ @two.id ] } }
    assert_equal [ @two ], nobody.reload.assignees.to_a
  end

  test "a recurring task can go to several people, and this period's task follows" do
    recurring = recurring_tasks(:garbage_night) # one is responsible
    task = recurring.instance_for

    patch workstream_recurring_task_url(workstreams(:garbage), recurring), params: { recurring_task: { responsible_ids: [ @one.id, @two.id ] } }
    assert_redirected_to workstream_url(workstreams(:garbage))
    assert_equal [ @one, @two ].sort_by(&:name), recurring.reload.responsibles.to_a
    assert_equal [ @one, @two ].sort_by(&:name), task.reload.assignees.to_a
  end

  test "this period's task keeps its people if someone already changed them" do
    recurring = recurring_tasks(:garbage_night)
    task = recurring.instance_for
    task.release!(@one)

    patch workstream_recurring_task_url(workstreams(:garbage), recurring), params: { recurring_task: { responsible_ids: [ @one.id, @two.id ] } }
    assert_empty task.reload.assignees
  end

  test "the recurring task form picks its people in the same dropdown" do
    get edit_workstream_recurring_task_url(workstreams(:garbage), recurring_tasks(:garbage_night))
    assert_select "details.dropdown summary", text: /Jane Smith/
    assert_select "input[type=checkbox][name='recurring_task[responsible_ids][]'][value='#{@one.id}'][checked]"
    assert_select "[name='recurring_task[people_needed]']", count: 0
  end

  test "everyone on a finished shared task shows on the Contribution tab" do
    shared_task.update!(status: "completed")
    get tasks_url(tab: "contribution")
    assert_match "Jane and Mike · Garbage", response.body
  end
end
