require "application_system_test_case"

# CON-72: in the apps, the bell's count changes while you look at a page
class LiveBellTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  # Its own driver name: the user agent lists the bridge components, as the
  # apps' do, so the bell's controller loads
  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 1200 ], options: { name: :ios_app_with_bell } do |options|
    options.add_argument("--user-agent=Mozilla/5.0 (iPhone) Conduit iOS/2 (Turbo Native) bridge-components: [button menu bell]")
  end

  test "a new notification updates the bell without reloading the page" do
    member = users(:two)
    meal = Meal.create!(title: "Dinner", scheduled_at: 3.days.from_now, rsvp_deadline: 2.days.from_now)
    sign_in_as(member)
    visit tasks_url
    assert_selector "turbo-cable-stream-source[connected]", visible: false
    assert_selector "#native-bell[data-bridge-count='0']", visible: false

    perform_enqueued_jobs do
      member.in_app_notifications.create!(title: "RSVP for dinner", notification_type: "rsvp_deadline", notifiable: meal)
    end

    assert_selector "#native-bell[data-bridge-count='1']", visible: false
  end

  # Your own changes count even without the live connection (in case a web
  # view can't hold one): finishing a form on the page asks for the count
  test "claiming work that needed someone updates your bell from the page itself" do
    member = users(:two)
    task = Task.create!(title: "Mow the commons", user: users(:one), workstream: workstreams(:general), due_date: Date.current)
    member.in_app_notifications.create!(title: "Needs someone", notification_type: "task_needs_someone", notifiable: task)
    sign_in_as(member)
    visit tasks_url(tab: "available")
    assert_selector "#native-bell[data-bridge-count='1']", visible: false
    page.execute_script("document.querySelectorAll('turbo-cable-stream-source').forEach((source) => source.remove())")

    within("#task_#{task.id}") { click_button "Claim" }

    assert_text "It's yours"
    assert_selector "#native-bell[data-bridge-count='0']", visible: false
  end
end
