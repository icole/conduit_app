require "test_helper"

# The iOS and Android apps load these pages in Hotwire Native web views.
class TasksNativeTest < ActionDispatch::IntegrationTest
  # The App Store build before modals worked, the next iOS build, and Android.
  LEGACY_IOS = { "User-Agent" => "Conduit iOS (Turbo Native)" }.freeze
  NATIVE = { "User-Agent" => "Conduit iOS/2 (Turbo Native)" }.freeze
  ANDROID = { "User-Agent" => "Mozilla/5.0 (Linux; Android 15) Hotwire Native Android; Turbo Native Android" }.freeze

  def sign_in(user)
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  setup { sign_in users(:admin_user) }

  test "the Tasks screen keeps its own heading, since the apps hide their navigation bars" do
    get tasks_url, headers: NATIVE
    assert_select "title", "Tasks"
    assert_select "h1", "Tasks"
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

  test "the workstream screen keeps its in-page back link" do
    [ LEGACY_IOS, NATIVE, ANDROID ].each do |agent|
      get workstream_url(workstreams(:front_yard)), headers: agent
      assert_select "a[href='#{tasks_path(tab: "coverage")}']", { text: /Coverage/ }, agent["User-Agent"]
    end
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

  MODAL_FORMS = lambda do |test|
    [ test.new_workstream_url, test.edit_workstream_url(test.workstreams(:garbage)),
      test.edit_workstream_recurring_task_url(test.workstreams(:garbage), test.recurring_tasks(:garbage_night)) ]
  end

  test "modal forms keep their heading and Cancel link in the apps" do
    MODAL_FORMS.call(self).each do |url|
      [ LEGACY_IOS, NATIVE, ANDROID ].each do |agent|
        get url, headers: agent
        assert_select "h1", { minimum: 1 }, "#{url} #{agent['User-Agent']}"
        assert_select "a", { text: "Cancel" }, "#{url} #{agent['User-Agent']}"
      end
    end
  end

  test "modal forms submit with Turbo, so saving closes the sheet, except in the older iOS build" do
    MODAL_FORMS.call(self).each do |url|
      get url, headers: LEGACY_IOS
      assert_select "form[data-turbo='false']", 1, url

      [ NATIVE, ANDROID ].each do |agent|
        get url, headers: agent
        assert_select "form[data-turbo='false']", { count: 0 }, "#{url} #{agent['User-Agent']}"
      end
    end
  end

  test "the new task screen has a Cancel link back to where it came from" do
    get new_task_url(workstream_id: workstreams(:garbage).id), headers: NATIVE
    assert_select "h1", "New task"
    assert_select "a[href='#{workstream_path(workstreams(:garbage))}']", text: "Cancel"
  end
end
