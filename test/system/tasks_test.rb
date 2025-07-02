require "application_system_test_case"

class TasksTest < ApplicationSystemTestCase
  setup do
    @user_one = users(:one)
    @user_two = users(:two)
    @task = tasks(:one)                # User one's task with no assignment
    @assigned_task = tasks(:assigned_task)  # User one's task assigned to user two
    @received_task = tasks(:received_task)  # User two's task assigned to user one

    sign_in_user  # Signs in as user one by default
  end

  test "viewing tasks on dashboard shows only tasks assigned to current user" do
    visit dashboard_index_url

    # Should see tasks assigned to the current user
    assert_selector "div", text: @received_task.title

    # Should NOT see tasks created by the current user but assigned to someone else
    assert_no_selector "div", text: @assigned_task.title

    # Should NOT see tasks created by current user with no assignment
    assert_no_selector "div", text: @task.title
  end

  test "viewing tasks index shows all tasks with assignments" do
    visit tasks_url

    # Should see all tasks
    assert_selector "div", text: @task.title
    assert_selector "div", text: @assigned_task.title
    assert_selector "div", text: @received_task.title

    # Should see assignment badges for assigned tasks
    within "#task_#{@assigned_task.id}" do
      assert_selector "span", text: @user_two.name
    end

    within "#task_#{@received_task.id}" do
      assert_selector "span", text: @user_one.name
    end
  end

  test "filtering tasks by assignment on tasks index" do
    visit tasks_url

    # Click the dropdown for Assigned To
    find("label", text: /Assigned To/).click

    # Select to filter by current user
    click_on "Me"

    # Should see only tasks assigned to current user
    assert_selector "div", text: @received_task.title
    assert_no_selector "div", text: @assigned_task.title
    assert_no_selector "div", text: @task.title
  end

  test "creating a new task with assignment from tasks page" do
    visit tasks_url

    # Count existing tasks before creating a new one
    initial_task_count = all("#task-list-items > div").count

    # Open the new task form
    find("button[data-action='click->tasks#showForm']").click

    # Wait for the form to be visible
    assert_selector "#new-task-form", visible: true

    within "#new-task-form" do
      # Fill in the form
      fill_in "task[title]", with: "Test assigned task"
      fill_in "task[description]", with: "This is a test task with assignment"
      select @user_two.name, from: "task[assigned_to_user_id]"

      # Submit the form using the input directly
      find('input[type="submit"]').click
    end

    # Manually visit the tasks page again to ensure we see the updated content
    visit tasks_url

    # Verify the task was created by checking that the total count increased
    assert all("#task-list-items > div").count > initial_task_count

    # Verify our new task appears with the assignment
    # Using a more specific selector to avoid ambiguity
    assert_selector "#task-list-items div", text: "Test assigned task"

    # Find the specific task that was just created by looking for the exact title
    task_element = find("#task-list-items div", text: "Test assigned task", match: :prefer_exact)

    # Verify the task has the correct assigned user
    within task_element do
      assert_selector "span", text: @user_two.name
    end
  end

  test "editing task assignment" do
    visit tasks_url

    # Make sure the task exists before editing it
    assert_selector "#task_#{@task.id}"

    # Find and click edit for an existing task
    within "#task_#{@task.id}" do
      find("a[title='Edit']").click
    end

    # Check that we are on the edit page
    assert_selector "h2.card-title", text: "Edit Task"

    # Change the assignment - make sure we're targeting the correct form field
    select @user_two.name, from: "task_assigned_to_user_id"

    # Submit the form
    find('input[type="submit"][value="Update Task"]').click

    # Manually visit the tasks page again to ensure we see the updated content
    visit tasks_url

    # Use the task ID to find the specific task after the page reload
    task_element = find("#task_#{@task.id}")

    # Verify the task now has the user assigned to it
    within task_element do
      assert_selector "span", text: @user_two.name
    end
  end

  test "assignment dropdown not shown on dashboard" do
    visit dashboard_index_url

    # Open the new task form from dashboard
    find("input[placeholder='Add a new task...']").click

    # The assignment dropdown should not be present
    assert_no_selector "label", text: "Assign to"
  end

  test "switching users to verify assignment works both ways" do
    # First verify user one can see task assigned to them
    visit dashboard_index_url
    assert_selector "div", text: @received_task.title

    # Sign out
    visit "/logout"

    # Sign in as user two
    sign_in_user({
      provider: "google_oauth2",
      uid: "1234567890",
      info: {
        name: "Mike Davis",
        email: "mike@example.com"
      }
    })

    # User two should see tasks assigned to them
    visit dashboard_index_url
    assert_selector "div", text: @assigned_task.title
    assert_no_selector "div", text: @received_task.title
  end
end
