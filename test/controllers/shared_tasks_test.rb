require "test_helper"

# Tasks that need more than one person, through the pages people use.
class SharedTasksTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    delete logout_path
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  setup do
    @one, @two, @three = users(:one), users(:two), users(:three)
    sign_in @one # owns Garbage & Recycling
  end

  def shared_task(people: [ @one, @two ], needed: 2, workstream: workstreams(:garbage))
    Task.create!(title: "Facilitate the meeting", user: @one, workstream: workstream, people_needed: needed, assignees: people)
  end

  test "an owner can add a task that needs two people and put both on it" do
    post tasks_url, params: { task: { title: "Deep clean the bins", workstream_id: workstreams(:garbage).id,
                                      people_needed: 2, assignee_ids: [ @one.id, @two.id, "", "" ] } }
    task = Task.find_by!(title: "Deep clean the bins")
    assert_equal [ 2, [ @one, @two ].sort_by(&:name) ], [ task.people_needed, task.assignees.to_a ]
  end

  test "a member who doesn't own the workstream can only put themselves on it" do
    sign_in @three
    assert_no_difference("Task.count") do
      post tasks_url, params: { task: { title: "Sweep", workstream_id: workstreams(:general).id,
                                        people_needed: 2, assignee_ids: [ @three.id, @two.id ] } }
    end
    assert_response :unprocessable_entity
  end

  test "the task form has a picker per spot, showing as many as People needed" do
    task = shared_task
    get edit_task_url(task)
    assert_select "select[name='task[people_needed]'] option[selected][value='2']"
    assert_select "select[name='task[assignee_ids][]']", 4
    assert_select "[data-people-slots-target='slot']:not([hidden])", 2
    assert_select "select#task_assignee_ids_0 option[selected][value='#{[ @one, @two ].min_by(&:name).id}']"
  end

  test "My Tasks shows who you share a task with, and whose spot you're covering" do
    shared_task
    covered = shared_task(people: [ @two, @three ])
    sign_in @three
    covered.release!(@three)
    sign_in @one
    covered.claim!(@one)

    get tasks_url(tab: "my")
    assert_select "#task_#{covered.id}", text: /Covering for Alice/
    assert_select "#task_#{covered.id}", text: /With Mike/
  end

  test "Available shows how many more people a shared task needs, and anyone not on it can claim a spot" do
    task = shared_task(people: [ @two ])
    get tasks_url(tab: "available")
    assert_select "#task_#{task.id}", text: /Needs 1 more/
    assert_select "#task_#{task.id} form[action='#{claim_task_path(task)}']"

    patch claim_task_url(task)
    assert_equal [ @one, @two ].sort_by(&:name), task.reload.assignees.to_a
  end

  test "releasing your spot on a shared task leaves the others on it" do
    task = shared_task
    patch release_task_url(task)
    assert_equal [ @two ], task.reload.assignees.to_a
    assert_equal 1, task.open_spots
  end

  test "the workstream page lists everyone on a task, and Assign fills an open spot" do
    task = shared_task(people: [ @one ])
    get workstream_url(workstreams(:garbage))
    assert_select "#task_#{task.id}", text: /Needs 1 more/
    assert_select "#task_#{task.id} form input[type=hidden][name='task[assignee_ids][]'][value='#{@one.id}']"

    patch task_url(task, return_to: workstream_path(workstreams(:garbage))), params: { task: { assignee_ids: [ @one.id, @two.id ] } }
    assert_equal [ @one, @two ].sort_by(&:name), task.reload.assignees.to_a
    get workstream_url(workstreams(:garbage))
    assert_select "#task_#{task.id}", text: /#{[ @one, @two ].sort_by(&:name).map(&:name).to_sentence}/
  end

  test "a recurring task can be set to need two people, and this period's task follows" do
    recurring = recurring_tasks(:garbage_night) # one is responsible
    task = recurring.instance_for

    patch workstream_recurring_task_url(workstreams(:garbage), recurring),
          params: { recurring_task: { people_needed: 2, responsible_ids: [ @one.id, @two.id ] } }
    assert_redirected_to workstream_url(workstreams(:garbage))
    assert_equal [ @one, @two ].sort_by(&:name), recurring.reload.responsibles.to_a
    assert_equal [ 2, [ @one, @two ].sort_by(&:name) ], [ task.reload.people_needed, task.assignees.to_a ]
  end

  test "this period's task keeps its people if someone already changed them" do
    recurring = recurring_tasks(:garbage_night)
    task = recurring.instance_for
    task.release!(@one)

    patch workstream_recurring_task_url(workstreams(:garbage), recurring),
          params: { recurring_task: { people_needed: 2, responsible_ids: [ @one.id, @two.id ] } }
    assert_equal [ 1, [] ], [ task.reload.people_needed, task.assignees.to_a ]
  end

  test "the recurring task form has a picker per spot" do
    recurring = recurring_tasks(:garbage_night)
    get edit_workstream_recurring_task_url(workstreams(:garbage), recurring)
    assert_select "select[name='recurring_task[people_needed]']"
    assert_select "select[name='recurring_task[responsible_ids][]']", 4
  end

  test "each person on a finished shared task shows on the Contribution tab" do
    task = shared_task
    task.update!(status: "completed")
    get tasks_url(tab: "contribution")
    assert_match "Jane and Mike · Garbage", response.body # Jane Smith and Mike Davis
  end
end
