require "application_system_test_case"

class TasksTest < ApplicationSystemTestCase
  setup do
    @user_one = users(:one)
    @user_two = users(:two)
    @task = tasks(:one)                # User one's task with no assignment
    @assigned_task = tasks(:assigned_task)  # User one's task assigned to user two
    @received_task = tasks(:received_task)  # User two's task assigned to user one

    sign_in_as(@user_one)  # Sign in as fixture user one
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
    click_link "All tasks: backlog & priority order"

    # Check backlog tasks
    click_link "Backlog"
    assert_text @task.title

    # Check active tasks
    click_link "Active"
    assert_text @assigned_task.title
    assert_text @received_task.title

    # Should see assignment badges for assigned tasks (shows first name only)
    within "#task_#{@assigned_task.id}" do
      assert_selector "span", text: @user_two.name.split(" ").first
    end

    within "#task_#{@received_task.id}" do
      assert_selector "span", text: @user_one.name.split(" ").first
    end
  end

  test "filtering tasks by assignment on tasks index" do
    # Visit tasks URL, but make sure we see all tasks regardless of status
    visit tasks_path(view: "active")

    # Ensure the filter dropdown exists (icon button with filter dropdown)
    assert_selector ".dropdown.dropdown-end"

    # Use direct link to filter by current user instead of dropdown interaction
    # This avoids issues with dropdown visibility in test environment
    visit tasks_path(view: "active", assigned_to: @user_one.id)

    # Should see only tasks assigned to current user
    assert_text @received_task.title
    assert_no_text @assigned_task.title
    assert_no_text @task.title
  end

  test "assignee filter clear control has an accessible label" do
    visit tasks_path(view: "active", assigned_to: @user_one.id)

    assert_selector "a[aria-label='Clear assignee filter']"
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
      # user one owns this workstream, so may assign to others
      select workstreams(:garbage).name, from: "task[workstream_id]"

      # Use native select for user assignment
      select @user_two.name, from: "task[assigned_to_user_id]"

      # Submit the form
      click_on "Create Task"
    end

    # Wait for task creation to complete and page to reload
    assert_text "Task was successfully created"

    # Verify our new task appears with the assignment (first name only in badge)
    assert_text "Test assigned task"
    assert_text @user_two.name.split(" ").first
  end

  test "editing task assignment" do
    # Ensure the task has active status to be visible in the default view.
    # Only the workstream owner reassigns; user one owns this workstream.
    @task.update(status: "active", priority_order: 1, workstream: workstreams(:garbage))

    # Visit the edit page directly
    visit edit_task_path(@task)

    # Check that we are on the edit page
    assert_text "Edit Task"

    # Use native select for user assignment
    select @user_two.name, from: "task[assigned_to_user_id]"

    # Submit the form - use the button text instead of input value
    click_button "Update Task"

    # Should be redirected back to the tasks list
    assert_text "Task was successfully updated"

    # It's Mike's now, so it shows on the full board rather than My Tasks
    visit tasks_path(view: "active")
    assert_selector "#task_#{@task.id}"

    # Now verify that the task shows the new assignment (first name only)
    within "#task_#{@task.id}" do
      assert_selector "span", text: @user_two.name.split(" ").first
    end
  end

  test "dashboard shows assigned tasks without inline form" do
    visit dashboard_index_url

    # Tasks should be visible on the dashboard
    assert_text @received_task.title

    # The inline task creation form should not be on the dashboard
    assert_no_selector "input[placeholder='Add a new task...']"
  end

  test "switching users to verify assignment works both ways" do
    # First verify user one can see task assigned to them
    visit dashboard_index_url
    assert_text @received_task.title

    # Clear the session completely and reset
    Capybara.reset_sessions!

    # Sign in as user two (fixture user)
    sign_in_as(@user_two)

    # User two should see tasks assigned to them
    visit dashboard_index_url
    assert_text "Review Pull Request #42"  # Use the full title with #42
    assert_no_text @received_task.title
  end

  test "switching tabs keeps the page and updates the address" do
    visit tasks_url
    assert_selector "nav[aria-label='Task views'] a[aria-current='page']", text: "My Tasks"

    click_link "Coverage"
    assert_selector "#ongoing-operations", text: "Garbage & Recycling Coordinator"
    assert_current_path tasks_path(tab: "coverage")

    click_link "Available"
    assert_selector "[data-priority-group='important']", text: "Restock common house pantry"
  end

  test "releasing a recurring duty and a neighbour claiming it" do
    visit tasks_url
    within "#recurring-responsibilities" do
      assert_text "Take out garbage & recycling"
      accept_confirm { click_button "Can't do it →" }
    end
    assert_text "Released to the queue"
    assert_no_selector "#recurring-responsibilities", text: "Take out garbage"

    Capybara.reset_sessions!
    sign_in_as(@user_two)
    visit tasks_url(tab: "available")
    card = find("[data-priority-group='essential'] [id^='task_']", text: "Take out garbage & recycling")
    within(card) do
      assert_text "Released by Jane"
      click_button "Claim"
    end
    assert_text "It's yours"

    click_link "My Tasks"
    within "#assigned-to-you" do
      assert_text "Take out garbage & recycling"
      assert_text "Covering for Jane"
    end
  end

  test "marking a responsibility done removes it from My Tasks" do
    visit tasks_url
    within "#recurring-responsibilities" do
      find("button[aria-label='Mark “Take out garbage & recycling” done']").click
    end
    assert_no_selector "#recurring-responsibilities", text: "Take out garbage"
    assert Task.find_by(title: "Take out garbage & recycling").completed?
  end

  test "contribution shows the period's picture and steps back a period" do
    visit tasks_url
    click_link "Contribution"
    period = ContributionPeriod.containing(Date.current, "semi_annual")
    within("#contribution-period") { assert_text period.label }
    assert_text "Each household relative to fair share"
    within("#areas-needing-help") { assert_text "Common House Wrangler" }

    click_link period.previous.label
    within("#contribution-period") { assert_text period.previous.label }
  end

  test "on a phone, card actions sit under the details instead of squeezing them" do
    page.driver.browser.manage.window.resize_to(375, 1400)
    Task.create!(title: "Swept the porch", user: @user_one, workstream: workstreams(:general), estimated_minutes: 20,
                 status: "completed", completed_by: @user_one, completed_at: Time.current)

    visit tasks_url
    card = find("#recurring-responsibilities [id^='task_']", text: "Take out garbage & recycling")
    badges = card.find("[data-task-details]")
    release = card.find_button("Can't do it →")
    assert_operator release.rect.y, :>, badges.rect.y + badges.rect.height - 1
    assert_operator card.find("p", text: "Take out garbage & recycling").rect.width, :>, 220

    click_link "Contribution"
    title = find("#recently-completed p", text: "Swept the porch")
    assert title.evaluate_script("this.scrollWidth <= this.clientWidth"), "completed titles shouldn't be cut off"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "coverage is a plain grouped list on phones and coloured cards on wider screens" do
    covered = "#workstream_#{workstreams(:garbage).id}"
    uncovered = "#workstream_#{workstreams(:common_house).id}"
    left_border = ->(card) { find(card).evaluate_script("getComputedStyle(this).borderLeftWidth") }
    owner_below_badge = lambda do |card|
      badge = find("#{card} [data-coverage-type]")
      owner = find("#{card} [data-coverage-owner]")
      owner.rect.y >= badge.rect.y + badge.rect.height - 1
    end

    page.driver.browser.manage.window.resize_to(375, 1400)
    visit tasks_url(tab: "coverage")
    [ covered, uncovered ].each do |card|
      assert_equal "0px", left_border.call(card), "phone: no coloured edge on #{card}"
      assert_no_selector "#{card} [data-coverage-type]", visible: true
      assert_selector "#{card} [data-coverage-owner]"
    end
    list = find("#ongoing-operations [data-coverage-list]")
    assert_equal "1px", list.evaluate_script("getComputedStyle(this).borderTopWidth"), "phone: one bordered list per section"

    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit tasks_url(tab: "coverage")
    [ covered, uncovered ].each do |card|
      assert_equal "4px", left_border.call(card), "wide: coloured edge on #{card}"
      assert_not owner_below_badge.call(card), "wide: owner sits beside the type on #{card}"
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "owner lines line up across a row of coverage cards" do
    RecurringTask.create!(workstream: workstreams(:general), title: "Unheld chore", frequency: "weekly",
                          estimated_minutes: 20, created_by: users(:admin_user))
    visit tasks_url(tab: "coverage")
    assert_selector "#ongoing-operations [data-coverage-owner]", minimum: 2
    rows = all("#ongoing-operations [data-coverage-owner]").group_by { |el| el.find(:xpath, "ancestor::a[1]").rect.y.round }
    mixed = rows.values.select { |owners| owners.map { |o| o.find(:xpath, "ancestor::a[1]").text.include?("without a responsible person") }.uniq.size == 2 }
    assert mixed.any?, "expected a row pairing a card with a gap note and one without"
    rows.each_value do |owners|
      assert_equal 1, owners.map { |o| o.rect.y.round }.uniq.size, "owner lines in a row should align"
    end
  end

  test "admins make a task repeat from the one Add task form" do
    Capybara.reset_sessions!
    sign_in_as(users(:admin_user))
    visit workstream_url(workstreams(:common_house))
    click_link "+ Add task"

    assert_field "Due Date (optional)"
    assert_no_field "Priority"
    select "Weekly", from: "Repeats"
    assert_no_field "Due Date (optional)"
    assert_field "Priority"
    assert_selector "label", text: "Responsible each period"

    fill_in "Title", with: "Clean shared kitchen"
    select "Medium · ~45 min", from: "Estimated effort"
    select "Essential", from: "Priority"
    click_button "Create Task"

    assert_text "“Clean shared kitchen” repeats weekly"
    assert_selector "[id^='recurring_task_']", text: "Clean shared kitchen"
    assert RecurringTask.exists?(title: "Clean shared kitchen", frequency: "weekly", priority: "essential")
  end

  test "deleting open work updates the count, and Undo comes back to the workstream" do
    Capybara.reset_sessions!
    sign_in_as(users(:admin_user))
    task = Task.create!(title: "Fix the gate", user: users(:admin_user), workstream: workstreams(:common_house))
    visit workstream_url(workstreams(:common_house))
    before = find("#open-work-count").text.to_i

    within("#task_#{task.id}") { accept_confirm { click_button "Delete" } }
    assert_no_selector "#task_#{task.id}"
    assert_selector "#open-work-count", text: (before - 1).to_s

    click_button "Undo"
    assert_current_path workstream_path(workstreams(:common_house))
    assert_selector "#task_#{task.id}"
  end
end
