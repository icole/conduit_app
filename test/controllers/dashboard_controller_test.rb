require "test_helper"
require "minitest/mock"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "dashboard index loads successfully with timeline items" do
    sign_in_user
    get dashboard_index_url
    assert_response :success
    assert_not_nil assigns(:timeline_items)
  end

  test "the dashboard greets you by first name for the time of day" do
    member = users(:two)
    sign_in_user(uid: member.uid, name: member.name, email: member.email)

    travel_to Time.zone.local(2026, 10, 5, 19, 30) do
      get dashboard_index_url
    end

    assert_select "h1", text: "Good evening, Mike."
  end

  test "the dashboard sums up the coming week's meals and the ones without a cook" do
    sign_in_user
    get dashboard_index_url

    assert_select "[data-testid='week-summary']", text: /3 meals this week\s*·\s*2 still need a cook/
  end

  test "the apps' Home is the almanac too: greeting, the week's meals, and dates by day" do
    sign_in_user
    get dashboard_index_url, headers: { "User-Agent" => "Conduit iOS/2 (Turbo Native)" }

    assert_select "h1", text: /\AGood (morning|afternoon|evening), /
    assert_select "[data-testid='week-summary']"
    assert_select "#coming-up", text: "Coming up"
  end

  # There's no backlog any more: what's yours and open is what's yours to do
  test "your open tasks show, whatever their old backlog status, and finished ones don't" do
    member = users(:two)
    sign_in_user(uid: member.uid, name: member.name, email: member.email)
    backlogged = Task.create!(title: "Oil the gate hinges", user: member, workstream: workstreams(:general), status: "backlog")
    backlogged.assignees << member
    done = Task.create!(title: "Wash the windows", user: member, workstream: workstreams(:general), status: "completed")
    done.assignees << member

    get dashboard_index_url
    assert_includes assigns(:tasks), backlogged
    assert_not_includes assigns(:tasks), done
  end

  test "editing a task has no Status menu: done is Mark done, not a setting" do
    sign_in_user(uid: users(:one).uid, name: users(:one).name, email: users(:one).email)
    get edit_task_url(tasks(:one))

    assert_select "select[name='task[status]']", count: 0
  end

  test "dashboard timeline includes upcoming meals sorted by date" do
    sign_in_user
    get dashboard_index_url
    assert_response :success

    timeline = assigns(:timeline_items)
    meals_in_timeline = timeline.select { |item| item[:type] == :meal }
    assert meals_in_timeline.any?, "Timeline should include meals"

    # Verify sorted by start time
    times = timeline.map { |item| item[:start_time] }
    assert_equal times, times.sort
  end

  test "dashboard timeline excludes cancelled and past meals" do
    sign_in_user
    get dashboard_index_url

    timeline = assigns(:timeline_items)
    meal_titles = timeline.select { |item| item[:type] == :meal }.map { |item| item[:meal].title }
    assert_not_includes meal_titles, "Cancelled Dinner"
    assert_not_includes meal_titles, "Past Community Meal"
  end

  test "dashboard timeline is limited to 10 items" do
    sign_in_user
    get dashboard_index_url

    timeline = assigns(:timeline_items)
    assert timeline.length <= 10
  end

  test "dashboard loads tasks assigned to current user" do
    sign_in_user
    get dashboard_index_url
    assert_response :success
    assert_not_nil assigns(:tasks)
  end

  test "dashboard renders lazy turbo frame for documents" do
    sign_in_user
    get dashboard_index_url
    assert_response :success
    assert_select "turbo-frame#dashboard-documents[src]"
    assert_select "turbo-frame#dashboard-documents a[href='#{documents_path}'][data-turbo-frame='_top']"
  end

  test "dashboard renders view all calendar link with turbo frame top" do
    sign_in_user
    get dashboard_index_url
    assert_response :success
    assert_select "a[href='#{calendar_index_path}']"
  end

  test "dashboard renders view all tasks link" do
    sign_in_user
    get dashboard_index_url
    assert_response :success
    assert_select "a[href='#{tasks_path}']"
  end

  test "documents_section returns drive files when configured" do
    sign_in_user
    community = communities(:crow_woods)
    community.update!(settings: (community.settings || {}).merge("google_drive_folder_id" => "root123"))

    mock_service = Minitest::Mock.new
    mock_service.expect(:configured?, true)
    mock_service.expect(:recent_files, {
      files: [
        { id: "f1", name: "Meeting Notes", web_link: "https://drive.google.com/f1", mime_type: "application/vnd.google-apps.document", updated_at: 1.hour.ago },
        { id: "f2", name: "Budget", web_link: "https://drive.google.com/f2", mime_type: "application/vnd.google-apps.spreadsheet", updated_at: 2.hours.ago }
      ],
      error: nil
    })

    GoogleDriveBrowseService.stub(:new, mock_service) do
      get documents_section_dashboard_index_url
    end

    assert_response :success
    assert assigns(:drive_files).length == 2
    assert_select "turbo-frame#dashboard-documents"
    mock_service.verify
  end

  test "documents_section handles drive not configured" do
    sign_in_user
    community = communities(:crow_woods)
    community.update!(settings: {})

    mock_service = Minitest::Mock.new
    mock_service.expect(:configured?, false)

    GoogleDriveBrowseService.stub(:new, mock_service) do
      get documents_section_dashboard_index_url
    end

    assert_response :success
    assert_equal [], assigns(:drive_files)
    mock_service.verify
  end

  test "dashboard does not include posts" do
    sign_in_user
    get dashboard_index_url
    assert_response :success
    assert_nil assigns(:posts)
    assert_nil assigns(:post)
  end
end
