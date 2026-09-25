require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @community = communities(:crow_woods)
    ActsAsTenant.current_tenant = @community
    @user = users(:one)
    @task = tasks(:one)
    sign_in_user({ uid: @user.uid, name: @user.name, email: @user.email })
    # Re-set tenant after sign_in_user which may have cleared it
    ActsAsTenant.current_tenant = @community
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "should get index" do
    get tasks_url
    assert_response :success
  end

  test "should get new" do
    get new_task_url
    assert_response :success
  end

  test "should create task and redirect to tasks when coming from tasks" do
    assert_difference("Task.count") do
      post tasks_url,
           params: { task: { title: "Test Task", description: "Test description", workstream_id: workstreams(:general).id } },
           headers: { "HTTP_REFERER" => tasks_url }
    end
    # An unassigned task is open work in the queue
    assert_redirected_to tasks_url(tab: "available")
  end

  test "should create task and redirect to dashboard when not coming from tasks" do
    assert_difference("Task.count") do
      post tasks_url,
           params: { task: { title: "Test Task", description: "Test description", workstream_id: workstreams(:general).id } },
           headers: { "HTTP_REFERER" => dashboard_index_url }
    end
    assert_redirected_to dashboard_index_url
  end

  test "should get edit" do
    get edit_task_url(@task)
    assert_response :success
  end

  test "edit page should show users in assignment dropdown" do
    other_user = users(:two)
    get edit_task_url(@task)
    assert_response :success
    assert_select "input[name='task[assigned_to_user_id]'][type='hidden']"
    assert_select "[data-controller='user-select']" do
      assert_select "[data-name='#{@user.name}']"
      assert_select "[data-name='#{other_user.name}']"
      assert_select "[data-name='Unassigned']"
    end
  end

  test "index page should show users in assignment dropdown for new task form" do
    other_user = users(:two)
    get tasks_url
    assert_response :success
    assert_select "input[name='task[assigned_to_user_id]'][type='hidden']"
    assert_select "[data-controller='user-select']" do
      assert_select "[data-name='#{@user.name}']"
      assert_select "[data-name='#{other_user.name}']"
      assert_select "[data-name='Unassigned']"
    end
  end

  test "should update task and redirect to tasks" do
    patch task_url(@task),
          params: { task: { title: "Updated Task", description: "Updated description", status: "completed" } }
    assert_redirected_to tasks_url

    @task.reload
    assert_equal "Updated Task", @task.title
    assert_equal "Updated description", @task.description
    assert_equal "completed", @task.status
  end

  test "should destroy task and redirect to tasks when coming from tasks" do
    assert_difference("Task.count", -1) do
      delete task_url(@task), headers: { "HTTP_REFERER" => tasks_url }
    end
    assert_redirected_to tasks_url
  end

  test "should destroy task and redirect to dashboard when not coming from tasks" do
    assert_difference("Task.count", -1) do
      delete task_url(@task), headers: { "HTTP_REFERER" => dashboard_index_url }
    end
    assert_redirected_to dashboard_index_url
  end

  test "should filter tasks by view" do
    # Create a completed task
    Task.create!(
      title: "Completed Task",
      description: "This task is done",
      status: "completed",
      user: @user,
      workstream: workstreams(:general)
    )

    # Test active filter
    get tasks_url(view: "active")
    assert_response :success
    assert_match(/Active/, response.body)

    # Test completed filter
    get tasks_url(view: "completed")
    assert_response :success
    assert_match(/Completed Task/, response.body)

    # Test backlog filter
    get tasks_url(view: "backlog")
    assert_response :success
    assert_match(/Backlog/, response.body)
  end

  test "should prioritize task from backlog" do
    task = Task.create!(
      title: "Backlog Task",
      description: "This task is in backlog",
      status: "backlog",
      user: @user,
      workstream: workstreams(:general)
    )

    assert_equal "backlog", task.status
    assert_nil task.priority_order

    patch prioritize_task_url(task)
    assert_redirected_to tasks_url

    task.reload
    assert_equal "active", task.status
    assert_not_nil task.priority_order
  end

  test "should move task back to backlog" do
    task = Task.create!(
      title: "Active Task",
      description: "This task is active",
      status: "active",
      priority_order: 1,
      user: @user,
      workstream: workstreams(:general)
    )

    assert_equal "active", task.status
    assert_equal 1, task.priority_order

    patch move_to_backlog_task_url(task)
    assert_redirected_to tasks_url

    task.reload
    assert_equal "backlog", task.status
    assert_nil task.priority_order
  end

  test "should reorder tasks" do
    # Create multiple active tasks
    task1 = Task.create!(title: "Task 1", status: "active", priority_order: 1, user: @user, workstream: workstreams(:general))
    task2 = Task.create!(title: "Task 2", status: "active", priority_order: 2, user: @user, workstream: workstreams(:general))
    task3 = Task.create!(title: "Task 3", status: "active", priority_order: 3, user: @user, workstream: workstreams(:general))
    task4 = Task.create!(title: "Task 4", status: "active", priority_order: 4, user: @user, workstream: workstreams(:general))
    task5 = Task.create!(title: "Task 5", status: "active", priority_order: 5, user: @user, workstream: workstreams(:general))

    # Move task1 to position 3
    patch reorder_task_url(task1), params: { priority_order: 3 }
    assert_response :success

    task1.reload
    assert_equal 3, task1.priority_order
  end

  test "creating a task without a workstream is rejected" do
    assert_no_difference("Task.count") do
      post tasks_url, params: { task: { title: "Orphan" } }
    end
    assert_response :unprocessable_entity
  end

  test "creating a task assigned to yourself lands on My Tasks" do
    post tasks_url,
         params: { task: { title: "Mine", workstream_id: workstreams(:general).id, assigned_to_user_id: @user.id, estimated_minutes: 45 } },
         headers: { "HTTP_REFERER" => tasks_url }
    task = Task.find_by!(title: "Mine")
    assert_equal @user, task.assigned_to_user
    assert_equal 45, task.estimated_minutes
    assert_redirected_to tasks_url(tab: "my")
  end

  test "a member who doesn't own the workstream cannot assign a task to someone else" do
    assert_no_difference("Task.count") do
      post tasks_url, params: { task: { title: "For Mike", workstream_id: workstreams(:front_yard).id, assigned_to_user_id: users(:two).id } }
    end
    assert_response :unprocessable_entity
  end

  test "the workstream owner can assign a task to someone else" do
    assert_difference("Task.count") do
      post tasks_url, params: { task: { title: "For Mike", workstream_id: workstreams(:garbage).id, assigned_to_user_id: users(:two).id } }
    end
    assert_equal users(:two), Task.find_by!(title: "For Mike").assigned_to_user
  end

  test "a member cannot reassign someone else's task to a third person" do
    task = tasks(:assigned_task) # assigned to two, in General (owned by admin)
    patch task_url(task), params: { task: { assigned_to_user_id: users(:three).id } }
    assert_response :unprocessable_entity
    assert_equal users(:two), task.reload.assigned_to_user
  end

  test "the task form asks for a workstream (open ones only) and an effort estimate" do
    workstreams(:front_yard).close!
    get new_task_url(workstream_id: workstreams(:garbage).id)
    assert_response :success
    assert_select "select[name='task[workstream_id]'][required]" do
      assert_select "option[selected][value='#{workstreams(:garbage).id}']"
      assert_select "option[value='#{workstreams(:front_yard).id}']", count: 0
    end
    assert_select "select[name='task[estimated_minutes]']"
  end

  test "members who own nothing can only assign tasks to themselves" do
    member = users(:three)
    delete logout_path
    sign_in_user({ uid: member.uid, name: member.name, email: member.email })
    get new_task_url
    assert_select "[data-controller='user-select']" do
      assert_select "[data-name='#{member.name}']"
      assert_select "[data-name='#{users(:two).name}']", count: 0
    end
  end

  test "My Tasks splits recurring responsibilities from one-off assignments" do
    get tasks_url
    assert_response :success
    assert_select "nav[aria-label='Task views'] a[aria-current='page']", text: "My Tasks"
    assert_select "#recurring-responsibilities", text: /Take out garbage & recycling/
    assert_select "#assigned-to-you", text: /Setup Development Environment/
    assert_select "#assigned-to-you", text: /Review Pull Request/, count: 0
    assert_no_match "Refactor Authentication System", response.body # completed work lives in Contribution
    assert_select "form[action='#{release_task_path(Task.find_by!(recurring_task: recurring_tasks(:garbage_night)))}']"
  end

  test "Available lists open work essential first with a claim action" do
    recurring_tasks(:pantry_restock).update!(priority: "essential")
    get tasks_url(tab: "available")
    assert_response :success
    groups = css_select("[data-priority-group]").map { |g| g["data-priority-group"] }
    assert_equal %w[essential important], groups
    assert_select "[data-priority-group='essential']", text: /Restock common house pantry/
    assert_select "[data-priority-group='important']", text: /Complete Project Documentation/
    assert_select "form[action='#{claim_task_path(tasks(:one))}']"
  end

  test "Coverage shows every open workstream grouped by type with its status" do
    get tasks_url(tab: "coverage")
    assert_response :success
    assert_select "#ongoing-operations #workstream_#{workstreams(:garbage).id}", text: /Covered/
    assert_select "#ongoing-operations #workstream_#{workstreams(:common_house).id}", text: /Needs owner/
    assert_select "#one-time-projects #workstream_#{workstreams(:front_yard).id}", text: /Mike Davis/
    assert_select "a[href='#{new_workstream_path}']", count: 0
  end

  test "admins can start a workstream from Coverage" do
    delete logout_path
    admin = users(:admin_user)
    sign_in_user({ uid: admin.uid, name: admin.name, email: admin.email })
    get tasks_url(tab: "coverage")
    assert_select "a[href='#{new_workstream_path}']"
  end

  test "the backlog and priority board is still reachable from My Tasks" do
    get tasks_url
    assert_select "a[href='#{tasks_path(view: "active")}']"
    get tasks_url(view: "backlog")
    assert_response :success
    assert_match "Complete Project Documentation", response.body
  end

  test "releasing your instance sends it to the queue and broadcasts it" do
    task = recurring_tasks(:garbage_night).instance_for
    assert_enqueued_with(job: CoverageBroadcastJob) do
      patch release_task_url(task)
    end
    assert_redirected_to tasks_url(tab: "my")
    assert_nil task.reload.assigned_to_user
    assert_equal @user, task.released_by
  end

  test "you can't release someone else's task" do
    patch release_task_url(tasks(:assigned_task))
    assert_redirected_to tasks_url(tab: "my")
    assert_equal users(:two), tasks(:assigned_task).reload.assigned_to_user
  end

  test "claiming open work assigns it to you" do
    patch claim_task_url(tasks(:one))
    assert_redirected_to tasks_url(tab: "available")
    assert_equal @user, tasks(:one).reload.assigned_to_user
  end

  test "an instance you picked up for someone else shows as assigned, covering for them" do
    task = recurring_tasks(:garbage_night).instance_for
    task.release!(@user)
    delete logout_path
    member = users(:three)
    sign_in_user({ uid: member.uid, name: member.name, email: member.email })
    task.claim!(member)

    get tasks_url
    assert_select "#recurring-responsibilities", text: /Take out garbage/, count: 0
    assert_select "#assigned-to-you", text: /Covering for Jane/
  end

  test "the page has four tabs" do
    get tasks_url
    assert_select "nav[aria-label='Task views'] a", count: 4
    assert_select "nav[aria-label='Task views'] a", text: "Contribution"
  end

  test "Contribution leads with the collective picture for the current period" do
    users(:one).update!(household: households(:smith_household))
    users(:two).update!(household: households(:jones_household))
    Task.create!(title: "Mow common lawn", user: @user, workstream: workstreams(:garbage), estimated_minutes: 90,
                 status: "completed", completed_by: @user, completed_at: Time.current)

    get tasks_url(tab: "contribution")
    assert_response :success
    period = ContributionPeriod.containing(Date.current, "semi_annual")
    assert_select "#contribution-period", text: /#{period.label}/
    assert_select "#fair-share", text: /0.8 hrs/
    household_names = css_select("[data-household]").map { |h| h["data-household"] }
    assert_equal [ "Jones Unit", "The Smith Family" ], household_names
    assert_select "#areas-needing-help", text: /Common House Wrangler/
    assert_select "#recently-completed", text: /Mow common lawn/
  end

  test "Contribution can step back to an earlier period" do
    period = ContributionPeriod.containing(Date.current, "semi_annual").previous
    get tasks_url(tab: "contribution", period: period.start_date.iso8601)
    assert_select "#contribution-period", text: /#{period.label}/
    assert_select "a[href='#{tasks_path(tab: "contribution", period: period.next.start_date.iso8601)}']"
  end

  test "My Tasks has no completed-work record" do
    get tasks_url
    assert_select "#recently-completed", count: 0
  end

  test "deleting from a Turbo page removes the task's row in place" do
    delete task_url(@task), as: :turbo_stream
    assert_response :success
    assert_match %(<turbo-stream action="remove" target="task_#{@task.id}">), response.body
  end
end
