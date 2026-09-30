require "test_helper"

# Marking work done, seeing what you finished, and taking it back.
class TaskCompletionTest < ActionDispatch::IntegrationTest
  FRAME = { "Turbo-Frame" => "tasks_content" }.freeze

  def sign_in(user)
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  setup do
    @user = users(:one)
    @task = tasks(:received_task) # assigned to one
    sign_in @user
  end

  test "marking a task done offers Undo, and Undo puts it back as it was" do
    patch complete_task_url(@task, return_to: tasks_path(tab: "my")), headers: FRAME
    assert_redirected_to tasks_path(tab: "my")
    assert @task.reload.completed?
    assert_equal @user, @task.completed_by

    # The Tasks tabs load in a frame, so the toast comes with the frame
    get tasks_url(tab: "my"), headers: FRAME
    assert_select "turbo-frame#tasks_content #undo-notification", text: /Marked .Setup Development Environment. done/ do
      assert_select "form[action='#{reopen_task_path(@task, return_to: tasks_path(tab: 'my'))}']"
    end

    post reopen_task_url(@task, return_to: tasks_path(tab: "my")), headers: FRAME
    assert_redirected_to tasks_path(tab: "my")
    @task.reload
    assert_equal [ "active", nil, nil, @user ], [ @task.status, @task.completed_at, @task.completed_by, @task.assigned_to_user ]
  end

  test "the Undo toast also shows on a full page load, in the page's toast area" do
    patch complete_task_url(@task, return_to: tasks_path(tab: "my"))
    follow_redirect!
    assert_select "#toasts #undo-notification-container #undo-notification[data-toast]", text: /done/
  end

  test "messages in the Tasks tabs are the same toast as everywhere else" do
    post reopen_task_url(@task, return_to: tasks_path(tab: "my")), headers: FRAME
    get tasks_url(tab: "my"), headers: FRAME
    assert_select "turbo-frame#tasks_content [data-toast].alert-success", text: /back on the list/
    assert_select ".alert-soft", count: 0
  end

  test "My Tasks lists what you finished in the last two weeks, and each can be marked not done" do
    recent = Task.create!(title: "Swept the porch", user: @user, assigned_to_user: @user, workstream: workstreams(:general), status: "completed")
    recent.update_columns(completed_at: 2.days.ago)
    done_for_you = Task.create!(title: "Covered the pantry", user: users(:two), assigned_to_user: users(:two), workstream: workstreams(:general),
                                status: "completed", completed_by: @user)
    old = Task.create!(title: "Raked leaves last year", user: @user, assigned_to_user: @user, workstream: workstreams(:general), status: "completed")
    old.update_columns(completed_at: 30.days.ago)
    someone_elses = Task.create!(title: "Mike's job", user: users(:two), assigned_to_user: users(:two), workstream: workstreams(:general), status: "completed")

    get tasks_url(tab: "my")
    assert_select "#recently-completed" do
      assert_select "summary", text: /Recently completed\s*2/
      assert_select "#task_#{recent.id}", text: /Swept the porch/
      assert_select "#task_#{recent.id} form[action='#{reopen_task_path(recent, return_to: tasks_path(tab: 'my'))}'] button[aria-label='Mark “Swept the porch” not done']"
      assert_select "#task_#{done_for_you.id}"
      assert_select "#task_#{old.id}", count: 0
      assert_select "#task_#{someone_elses.id}", count: 0
    end
  end

  test "Recently completed sits above the list, so nobody has to scroll to find it" do
    Task.create!(title: "Swept the porch", user: @user, assigned_to_user: @user, workstream: workstreams(:general), status: "completed")
    get tasks_url(tab: "my")
    assert_operator response.body.index("id=\"recently-completed\""), :<, response.body.index("id=\"my-work\"")
  end

  test "no Recently completed section when there's nothing to show" do
    get tasks_url(tab: "my")
    assert_select "#recently-completed", count: 0
  end

  test "undoing this period's recurring task makes it this period's open task again" do
    task = recurring_tasks(:garbage_night).instance_for # assigned to one
    patch complete_task_url(task)
    post reopen_task_url(task)
    task.reload
    assert_equal [ "active", @user, recurring_tasks(:garbage_night).period_for(Date.current).begin ],
                 [ task.status, task.assigned_to_user, task.period_start ]
    assert_equal task, recurring_tasks(:garbage_night).instance_for
  end

  test "you can't mark someone else's task done in a workstream you don't own" do
    task = tasks(:assigned_task) # assigned to two, in General (owned by admin)
    patch complete_task_url(task)
    assert_not task.reload.completed?
  end

  test "you can't undo someone else's completed task in a workstream you don't own" do
    task = Task.create!(title: "Mike's job", user: users(:two), assigned_to_user: users(:two), workstream: workstreams(:general), status: "completed")
    post reopen_task_url(task)
    assert task.reload.completed?
  end

  test "a workstream's owners can undo a completion in it" do
    task = Task.create!(title: "Bins out", user: users(:two), assigned_to_user: users(:two), workstream: workstreams(:garbage), status: "completed")
    post reopen_task_url(task) # one owns Garbage & Recycling
    assert_not task.reload.completed?
  end
end
