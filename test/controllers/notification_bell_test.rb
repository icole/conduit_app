require "test_helper"

# CON-72: a bell in the navbar counting what still needs you, and a list
# split into what needs you and updates
class NotificationBellTest < ActionDispatch::IntegrationTest
  setup do
    @member = users(:two)
    sign_in_user(uid: @member.uid, name: @member.name, email: @member.email)
    @meal = Meal.create!(title: "Dinner", scheduled_at: 3.days.from_now, rsvp_deadline: 2.days.from_now)
    @rsvp = notify("rsvp_deadline", "RSVP for Friday's dinner", @meal)
    @update = notify("cook_assigned", "Sam is cooking Friday", @meal)
  end

  def notify(kind, title, about)
    @member.in_app_notifications.create!(title: title, notification_type: kind, notifiable: about, action_url: meal_path(@meal))
  end

  test "the bell counts what needs you, and lists both" do
    get root_path

    assert_select "#notification-bell [data-count]", text: "1"
    assert_select "#notification-bell", text: /RSVP for Friday's dinner/
    assert_select "#notification-bell", text: /Sam is cooking Friday/
  end

  test "once you've RSVP'd the bell stops counting it" do
    @meal.meal_rsvps.create!(user: @member, status: "attending")
    get root_path

    assert_select "#notification-bell [data-count]", count: 0
  end

  test "opening a notification marks it read and goes to what it's about" do
    get notification_path(@update)

    assert_redirected_to meal_path(@meal)
    assert @update.reload.read?
    assert @update.resolved_at, "an update is dealt with once read"
  end

  test "each notification links straight to what it's about, not through a redirect" do
    get notifications_path

    assert_select "#updates a[href=?][data-notification-read-url-value=?]", meal_path(@meal), mark_read_notification_path(@update)
  end

  test "a notification's link only ever goes somewhere on this site" do
    @update.update!(action_url: "https://evil.example/phish")
    get notifications_path

    assert_select "#updates a[href=?]", "/phish"
  end

  test "coming back to the list shows it fresh, not a cached copy from before you opened one" do
    get notifications_path

    assert_select "meta[name='turbo-cache-control'][content='no-cache']"
  end

  test "the full list separates what needs you from updates" do
    get notifications_path

    assert_select "#needs-you", text: /RSVP for Friday's dinner/
    assert_select "#updates", text: /Sam is cooking Friday/
  end

  test "someone else's notification can't be opened" do
    theirs = users(:one).in_app_notifications.create!(title: "Theirs", notification_type: "general")
    get notification_path(theirs)

    assert_response :not_found
  end

  # The apps hide the navbar; their top bar shows a native bell instead, fed
  # by this element on every page (the "bell" bridge component)
  test "in the apps, every page hands the native bell its count" do
    get root_path, headers: { "User-Agent" => "Conduit iOS/2 (Turbo Native) bridge-components: [button menu bell]" }

    assert_select "a.hidden[data-controller='bridge--bell'][href='#{notifications_path}'][data-bridge-count='1']"
    assert_select "#notification-bell", count: 0
  end

  test "the website has its own bell, not the bridge one" do
    get root_path
    assert_select "[data-controller='bridge--bell']", count: 0
  end
end
