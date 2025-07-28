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
    assert_text @received_task.title

    # Should NOT see tasks created by the current user but assigned to someone else
    assert_no_text @assigned_task.title

    # Should NOT see tasks created by current user with no assignment
    assert_no_text @task.title
  end

  test "viewing tasks index shows all tasks with assignments" do
    visit tasks_url
    
    # Check backlog tasks
    click_link "Backlog"
    assert_text @task.title

    # Check active tasks  
    click_link "Active"
    assert_text @assigned_task.title
    assert_text @received_task.title

    # Should see assignment badges for assigned tasks
    within "#task_#{@assigned_task.id}" do
      assert_selector "span", text: @user_two.name
    end

    within "#task_#{@received_task.id}" do
      assert_selector "span", text: @user_one.name
    end
  end

  test "filtering tasks by assignment on tasks index" do
    # Visit tasks URL, but make sure we see all tasks regardless of status
    visit tasks_path(view: "active")

    # Ensure the dropdown exists
    assert_selector "label", text: /Assigned To/

    # Use direct link to filter by current user instead of dropdown interaction
    # This avoids issues with dropdown visibility in test environment
    visit tasks_path(view: "active", assigned_to: @user_one.id)

    # Should see only tasks assigned to current user
    assert_text @received_task.title
    assert_no_text @assigned_task.title
    assert_no_text @task.title
  end

  test "creating a new task with assignment from tasks page" do
    visit tasks_url

    # Open the new task form
    find("button[data-action='click->tasks#showForm']").click

    # Wait for the form to be visible
    assert_selector "#new-task-form", visible: true

    # Fill in the form fields
    within "#new_task" do
      fill_in "task[title]", with: "Test assigned task"
      select @user_two.name, from: "task[assigned_to_user_id]"

      # Submit the form
      click_on "Create Task"
    end

    # Wait for task creation to complete and page to reload
    assert_text "Task was successfully created"

    # Verify our new task appears with the assignment
    assert_text "Test assigned task"
    assert_text @user_two.name
  end

  test "editing task assignment" do
    # Ensure the task has active status to be visible in the default view
    @task.update(status: "active", priority_order: 1)

    # Visit the edit page directly
    visit edit_task_path(@task)

    # Check that we are on the edit page
    assert_text "Edit Task"

    # Change the assignment - make sure we're targeting the correct form field
    select @user_two.name, from: "task[assigned_to_user_id]"

    # Submit the form - use the button text instead of input value
    click_button "Update Task"

    # Should be redirected back to the tasks list
    assert_text "Community Tasks"

    # The task should appear in the list - it might take a moment to load
    assert_selector "#task_#{@task.id}"

    # Now verify that the task shows the new assignment
    within "#task_#{@task.id}" do
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
    assert_text @received_task.title

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
    assert_text @assigned_task.title
    assert_no_text @received_task.title
  end
end
