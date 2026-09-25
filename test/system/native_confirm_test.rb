require "application_system_test_case"

# The iOS app's web view has no handler for JavaScript dialogs, so
# window.confirm() silently returns false and every data-turbo-confirm action
# did nothing. In the apps, confirmations use an in-page dialog instead.
class NativeConfirmTest < ApplicationSystemTestCase
  # Its own driver name, so this phone-sized, app-flavoured browser doesn't
  # replace the :selenium one the other system tests share.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 1200 ], options: { name: :ios_app } do |options|
    options.add_argument("--user-agent=Mozilla/5.0 (iPhone) Conduit iOS (Turbo Native)")
  end

  # What WKWebView does without a WKUIDelegate
  def behave_like_ios_web_view
    page.execute_script("window.confirm = () => false")
  end

  test "removing a recurring task asks in the page and goes through" do
    sign_in_as(users(:admin_user))
    workstream = workstreams(:common_house)
    visit workstream_url(workstream)
    behave_like_ios_web_view

    within("#recurring_task_#{recurring_tasks(:pantry_restock).id}") { click_button "Remove" }
    within("dialog[open]") do
      assert_text "Remove this recurring task?"
      click_button "OK"
    end

    assert_no_selector "#recurring_task_#{recurring_tasks(:pantry_restock).id}"
    assert recurring_tasks(:pantry_restock).reload.discarded?
  end

  test "cancelling the in-page dialog leaves things alone" do
    sign_in_as(users(:admin_user))
    visit workstream_url(workstreams(:common_house))
    behave_like_ios_web_view

    within("#recurring_task_#{recurring_tasks(:pantry_restock).id}") { click_button "Remove" }
    within("dialog[open]") { click_button "Cancel" }

    assert_no_selector "dialog[open]"
    assert_selector "#recurring_task_#{recurring_tasks(:pantry_restock).id}"
    assert_not recurring_tasks(:pantry_restock).reload.discarded?
  end

  test "Can't do it releases the task from the app" do
    sign_in_as(users(:one))
    visit tasks_url
    behave_like_ios_web_view

    within("#recurring-responsibilities") { click_button "Can't do it →" }
    within("dialog[open]") { click_button "OK" }

    assert_text "Released to the queue"
    assert_nil Task.find_by!(title: "Take out garbage & recycling").assigned_to_user
  end
end
