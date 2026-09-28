require "application_system_test_case"

# The Tasks screen's Add Task form, as the iOS app shows it on a phone.
class NativeTaskFormTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 1200 ], options: { name: :ios_app_v2 } do |options|
    options.add_argument("--user-agent=Mozilla/5.0 (iPhone) Conduit iOS/2 (Turbo Native)")
  end

  test "Add Task on the Tasks screen offers Repeats" do
    sign_in_as(users(:admin_user))
    visit tasks_url
    click_button "Add Task"

    within("#new-task-form") do
      assert_field "Title"
      assert_select "Repeats", with_options: [ "Doesn't repeat", "Weekly" ]
    end
  end
end
