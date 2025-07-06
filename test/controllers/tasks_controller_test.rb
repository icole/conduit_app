require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @task = tasks(:one)
    sign_in_user({ uid: @user.uid, name: @user.name, email: @user.email })
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
           params: { task: { title: "Test Task", description: "Test description", status: "pending" } },
           headers: { "HTTP_REFERER" => tasks_url }
    end
    assert_redirected_to tasks_url
  end

  test "should create task and redirect to dashboard when not coming from tasks" do
    assert_difference("Task.count") do
      post tasks_url,
           params: { task: { title: "Test Task", description: "Test description", status: "pending" } },
           headers: { "HTTP_REFERER" => dashboard_index_url }
    end
    assert_redirected_to dashboard_index_url
  end

  test "should get edit" do
    get edit_task_url(@task)
    assert_response :success
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

  test "should filter tasks by status" do
    # Create a completed task
    Task.create!(
      title: "Completed Task",
      description: "This task is done",
      status: "completed",
      user: @user
    )

    # Test pending filter
    get tasks_url(status: "pending")
    assert_response :success
    assert_match(/Pending/, response.body)

    # Test completed filter
    get tasks_url(status: "completed")
    assert_response :success
    assert_match(/Completed Task/, response.body)
  end
end
