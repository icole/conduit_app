require "test_helper"

# The apps show a native top bar, with a back button, on every screen they push.
# The Android app with the "button" bridge component also has one on each tab's
# first screen and puts the page's main action in it; it shows forms as sheets.
# The iOS app has no top bar on a tab's first screen or in a sheet, so the page
# keeps those titles, back links and actions for it.
class NativeSheetsTest < ActionDispatch::IntegrationTest
  IOS = { "User-Agent" => "Conduit iOS/2 (Turbo Native)" }.freeze
  ANDROID = { "User-Agent" => "Mozilla/5.0 (Linux; Android 15) Hotwire Native Android; Turbo Native Android" }.freeze

  setup do
    user = users(:admin_user)
    sign_in_user({ uid: user.uid, name: user.name, email: user.email })
  end

  test "adding a task from a sheet tells the app to close it and refresh the screen beneath" do
    post tasks_url, params: { sheet: "1", task: { title: "Oil the hinges", workstream_id: workstreams(:general).id } }, headers: ANDROID
    assert_redirected_to turbo_refresh_historical_location_url

    # The app loads that URL, then reloads the screen under the sheet
    get turbo_refresh_historical_location_url, headers: ANDROID
    get tasks_url, headers: ANDROID
    assert_includes response.body, "Task was successfully created.", "the refreshed screen shows the toast"
  end

  test "adding a task from a full page in the app goes to the task, as before" do
    post tasks_url, params: { task: { title: "Oil the hinges", workstream_id: workstreams(:general).id } }, headers: IOS
    assert_response :redirect
    assert_not_includes response.location, "historical_location"
  end

  test "saving a task from a sheet closes it; from a full page it returns where it came from" do
    task = tasks(:one)
    back = workstream_path(task.workstream)

    patch task_url(task, return_to: back), params: { sheet: "1", task: { title: "Renamed in a sheet" } }, headers: ANDROID
    assert_redirected_to turbo_refresh_historical_location_url
    assert_equal "Task was successfully updated.", flash[:notice]

    patch task_url(task, return_to: back), params: { task: { title: "Renamed on a page" } }, headers: IOS
    assert_redirected_to back
  end

  test "a pushed screen leaves its back link and title to the app's top bar, but keeps its menu" do
    get meal_url(meals(:upcoming_meal)), headers: IOS
    assert_hidden_in_apps "a", text: /Back to Meals/
    assert_hidden_in_apps "h1", text: meals(:upcoming_meal).display_title
    assert_kept_without_top_bar "a", text: "Edit Meal"

    get workstream_url(workstreams(:general)), headers: IOS
    assert_hidden_in_apps "a", text: /All work/
  end

  test "Docs leaves its title to the top bar and keeps Drive where the app can't show it" do
    get documents_url, headers: IOS
    assert_hidden_in_apps "h1", text: "Documents"
    assert_kept_without_top_bar "a", text: /Open in Drive/
  end

  test "calendar event forms keep their heading everywhere, since they open as sheets" do
    get new_calendar_event_url, headers: ANDROID
    assert_kept_without_top_bar "h1", text: "New Calendar Event"
    assert_select "h1[class~='bridge-button:hidden']", count: 0
  end

  test "row actions are icons in the page for apps without a native top bar" do
    get workstream_url(workstreams(:general)), headers: IOS
    assert_kept_without_top_bar "a[aria-label^='Edit'] svg"

    reset! # someone with tasks of their own
    sign_in_user({ uid: users(:two).uid, name: users(:two).name, email: users(:two).email })
    get tasks_url(tab: "my"), headers: IOS
    assert_kept_without_top_bar "a[aria-label^='Edit'] svg"
  end

  test "forms keep Cancel for apps without a native top bar" do
    get edit_task_url(tasks(:one), return_to: tasks_path), headers: IOS
    assert_kept_without_top_bar "a", text: "Cancel"
  end

  private

  # Present, and not hidden in every app: only `bridge-button:hidden` (apps
  # whose native top bar replaces it) may hide it
  def assert_kept_without_top_bar(selector, text: nil)
    matching(selector, text).each do |el|
      assert_empty hidden_by(el, /\Anative:hidden\z/), "#{selector} #{text.inspect} is hidden in apps that have no native top bar"
    end
  end

  # Present for the website, hidden in every app (their top bar has it)
  def assert_hidden_in_apps(selector, text: nil)
    matching(selector, text).each do |el|
      assert_not_empty hidden_by(el, /\Anative:hidden\z/), "#{selector} #{text.inspect} still shows in the apps"
    end
  end

  def matching(selector, text)
    elements = css_select(selector).select { |el| text.nil? || (text.is_a?(Regexp) ? el.text.match?(text) : el.text.strip == text) }
    assert elements.any?, "no #{selector} with #{text.inspect}"
    elements
  end

  def hidden_by(element, pattern)
    [ element, *element.ancestors ].filter_map { |node| node["class"] if node.respond_to?(:[]) && node["class"] }
      .flat_map(&:split).grep(pattern)
  end
end
