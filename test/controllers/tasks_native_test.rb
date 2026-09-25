require "test_helper"

# The iOS and Android apps load these pages in Hotwire Native web views.
class TasksNativeTest < ActionDispatch::IntegrationTest
  NATIVE = { "User-Agent" => "Conduit iOS (Turbo Native)" }.freeze

  def sign_in(user)
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  setup { sign_in users(:admin_user) }

  test "the Tasks screen is titled for the native navigation bar" do
    get tasks_url, headers: NATIVE
    assert_select "title", "Tasks"
  end

  test "tabs switch inside the frame without proposing a native visit" do
    get tasks_url, headers: NATIVE
    assert_select "nav[aria-label='Task views'] a[data-turbo-frame='tasks_content']", count: 4
    assert_select "nav[aria-label='Task views'] a[data-turbo-action]", count: 0
  end

  test "the apps come back to the last tab, so pull-to-refresh stays put" do
    get tasks_url(tab: "coverage"), headers: NATIVE
    get tasks_url, headers: NATIVE
    assert_select "nav[aria-label='Task views'] a[aria-current='page']", text: "Coverage"
  end

  test "the web keeps the tab in the address instead" do
    get tasks_url(tab: "coverage")
    get tasks_url
    assert_select "nav[aria-label='Task views'] a[aria-current='page']", text: "My Tasks"
  end

  test "the workstream screen relies on the native back button" do
    get workstream_url(workstreams(:front_yard)), headers: NATIVE
    assert_select "a[href='#{tasks_path(tab: "coverage")}']", count: 0
  end

  test "workstream actions that return to the same screen replace it rather than push another" do
    get workstream_url(workstreams(:common_house)), headers: NATIVE
    assert_select "form[action='#{workstream_recurring_task_path(workstreams(:common_house), recurring_tasks(:pantry_restock))}'][data-turbo-action='replace']"

    get workstream_url(workstreams(:front_yard)), headers: NATIVE
    assert_select "form[action='#{close_workstream_path(workstreams(:front_yard))}'][data-turbo-action='replace']"
  end

  test "closing a project lands back on the project" do
    patch close_workstream_url(workstreams(:front_yard)), headers: NATIVE
    assert_redirected_to workstream_url(workstreams(:front_yard))
  end

  test "modal forms submit as full page loads and leave closing to the native Close button" do
    [ new_workstream_url, edit_workstream_url(workstreams(:garbage)),
      edit_workstream_recurring_task_url(workstreams(:garbage), recurring_tasks(:garbage_night)) ].each do |url|
      get url, headers: NATIVE
      assert_select "form[data-turbo='false']", 1, url
      assert_select "h1", 0, url
      assert_select "a", { text: "Cancel", count: 0 }, url
    end
  end

  test "the new task screen has no dead Cancel button" do
    get new_task_url(workstream_id: workstreams(:garbage).id), headers: NATIVE
    assert_select "button", { text: "Cancel", count: 0 }
    assert_select "a", { text: "Cancel", count: 0 }

    get new_task_url(workstream_id: workstreams(:garbage).id)
    assert_select "a[href='#{workstream_path(workstreams(:garbage))}']", text: "Cancel"
  end
end
