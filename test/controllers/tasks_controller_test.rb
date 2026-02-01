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
           params: { task: { title: "Test Task", description: "Test description" } },
           headers: { "HTTP_REFERER" => tasks_url }
    end
    # Task without due date or assignment goes to backlog
    assert_redirected_to tasks_url(view: "backlog")
  end

  test "should create task and redirect to dashboard when not coming from tasks" do
    assert_difference("Task.count") do
      post tasks_url,
           params: { task: { title: "Test Task", description: "Test description" } },
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
    assert_select "select[name='task[assigned_to_user_id]']" do
      assert_select "option", text: "Unassigned"
      assert_select "option", text: @user.name
      assert_select "option", text: other_user.name
    end
  end

  test "index page should show users in assignment dropdown for new task form" do
    other_user = users(:two)
    get tasks_url
    assert_response :success
    assert_select "select[name='task[assigned_to_user_id]']" do
      assert_select "option", text: "Unassigned"
      assert_select "option", text: @user.name
      assert_select "option", text: other_user.name
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
      user: @user
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
      user: @user
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
      user: @user
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
    task1 = Task.create!(title: "Task 1", status: "active", priority_order: 1, user: @user)
    task2 = Task.create!(title: "Task 2", status: "active", priority_order: 2, user: @user)
    task3 = Task.create!(title: "Task 3", status: "active", priority_order: 3, user: @user)
    task4 = Task.create!(title: "Task 4", status: "active", priority_order: 4, user: @user)
    task5 = Task.create!(title: "Task 5", status: "active", priority_order: 5, user: @user)

    # Move task1 to position 3
    patch reorder_task_url(task1), params: { priority_order: 3 }
    assert_response :success

    task1.reload
    assert_equal 3, task1.priority_order
  end
end
