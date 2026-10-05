require "test_helper"
require "minitest/mock"

# CON-34: the calendar feed, calendar sharing and meal sync all fell back to
# ENV["GOOGLE_CALENDAR_ID"], which is Crow Woods' calendar, whatever the
# community. Sharing also took calendar_id from the request, so a member could
# ask for writer access to any calendar the service account manages.
class CommunityCalendarIsolationTest < ActionDispatch::IntegrationTest
  OWN = "crow-woods@group.calendar.google.com".freeze

  setup do
    crow_woods = communities(:crow_woods)
    crow_woods.update!(settings: (crow_woods.settings || {}).merge("google_calendar_id" => OWN))
    @asked_for = []
  end

  def fake_calendar
    asked = @asked_for
    service = Object.new
    service.define_singleton_method(:get_events) { |calendar_id:, **| asked << calendar_id; { status: :success, events: [] } }
    service.define_singleton_method(:share_calendar_with_user) { |calendar_id:, **| asked << calendar_id; { status: :success } }
    service
  end

  def other_community_member(**attrs)
    ActsAsTenant.with_tenant(communities(:other_community)) do
      User.create!(name: "Other Member", email: "calendar-test@other.test", password: SecureRandom.base58(16), email_verified_at: Time.current, **attrs)
    end
  end

  test "a member's feed is their own community's calendar, named for it" do
    users(:one).update!(calendar_feed_token: "crow-token")
    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, fake_calendar) do
      get calendar_feed_url(token: "crow-token", format: :ics)
    end

    assert_response :success
    assert_equal [ OWN ], @asked_for
    assert_includes response.body, "X-WR-CALNAME:#{communities(:crow_woods).name}"
  end

  test "a community without a calendar has no feed, rather than Crow Woods'" do
    other_community_member.update!(calendar_feed_token: "other-token")
    host! "other.test"
    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, fake_calendar) do
      get calendar_feed_url(token: "other-token", format: :ics)
    end

    assert_response :not_found
    assert_empty @asked_for
  end

  test "sharing gives access to the member's own community calendar, whatever is asked for" do
    sign_in_user(uid: users(:one).uid, name: users(:one).name, email: users(:one).email)
    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, fake_calendar) do
      post calendar_shares_path, params: { calendar_id: "someone-elses@group.calendar.google.com" }
    end

    assert_equal [ OWN ], @asked_for
  end

  test "a community without a calendar shares nothing" do
    member = other_community_member(provider: "google_oauth2", uid: "other-uid")
    host! "other.test"
    sign_in_user(uid: member.uid, name: member.name, email: member.email)
    GoogleCalendarApiService.stub(:from_service_account_with_acl_scope, fake_calendar) do
      post calendar_shares_path
    end

    assert_empty @asked_for
    assert_not CalendarShare.exists?(user: member)
  end

  test "no subscribe button where there's no calendar to subscribe to" do
    member = other_community_member(provider: "google_oauth2", uid: "other-uid")
    host! "other.test"
    sign_in_user(uid: member.uid, name: member.name, email: member.email)
    get root_path

    assert_response :success
    assert_select "form[action='#{calendar_shares_path}']", count: 0
    assert_no_match "calendar/feed/", response.body
  end
end
