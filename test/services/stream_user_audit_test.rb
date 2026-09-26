# frozen_string_literal: true

require "test_helper"

# Drift between the Stream user list and our own: accounts that outlived their
# Conduit user, members missing from Stream, wrong teams, elevated roles.
class StreamUserAuditTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :deleted, :deactivated

    def initialize(users)
      @users = users
      @deleted = []
      @deactivated = []
    end

    def query_users(_filter, **_options)
      { "users" => @users }
    end

    def deactivate_user(id, **_options)
      @deactivated << id
      {}
    end

    def delete_user(id, **_options)
      @deleted << id
      {}
    end
  end

  def stream_user(id, role: "user", teams: [], name: nil)
    { "id" => id.to_s, "role" => role, "teams" => teams, "name" => name }
  end

  def ours
    ActsAsTenant.without_tenant { User.unscoped.order(:id).to_a }
  end

  test "flags Stream users with no Conduit account" do
    mine = ours.first
    client = FakeClient.new([
      stream_user(mine.id, teams: [ mine.community.slug ]),
      stream_user("999", name: "Departed"),
      stream_user("volt-dashboard")
    ])

    report = StreamUserAudit.new(client: client).call

    assert_equal [ "999", "volt-dashboard" ], report[:orphaned].map { |u| u[:id] }.sort
    assert_not report[:ok]
  end

  test "flags Conduit users missing from Stream" do
    client = FakeClient.new([])

    report = StreamUserAudit.new(client: client).call

    assert_equal ours.map { |u| u.id.to_s }.sort, report[:missing_from_stream].sort
  end

  test "flags a Stream user whose team does not match their community" do
    mine = ours.first
    client = FakeClient.new([ stream_user(mine.id, teams: [ "some-other-community" ]) ])

    report = StreamUserAudit.new(client: client).call

    wrong = report[:wrong_team].first
    assert_equal mine.id.to_s, wrong[:id]
    assert_equal [ mine.community.slug ], wrong[:expected]
    assert_equal [ "some-other-community" ], wrong[:actual]
  end

  test "flags roles other than user, since community admins must not be Stream admins" do
    mine = ours.first
    client = FakeClient.new([ stream_user(mine.id, role: "global_admin", teams: [ mine.community.slug ]) ])

    report = StreamUserAudit.new(client: client).call

    assert_equal [ "global_admin" ], report[:elevated_role].map { |u| u[:role] }
  end

  test "is ok when every Stream user matches a Conduit user with the right team and role" do
    client = FakeClient.new(ours.map { |u| stream_user(u.id, teams: [ u.community.slug ]) })

    report = StreamUserAudit.new(client: client).call

    assert report[:ok], report.inspect
    assert_empty report[:orphaned]
    assert_empty report[:missing_from_stream]
  end

  # Deliberately an explicit id list: some orphans are kept on purpose.
  test "removes only the ids it is given, and refuses ids that are not orphaned" do
    mine = ours.first
    # A realistic list: every real member plus one orphan, so the
    # environment-mismatch guard stays quiet.
    client = FakeClient.new(ours.map { |u| stream_user(u.id, teams: [ u.community.slug ]) } + [ stream_user("999") ])
    audit = StreamUserAudit.new(client: client)

    assert_raises StreamUserAudit::NotOrphaned do
      audit.deactivate_orphans!(ids: [ mine.id.to_s ])
    end

    assert_equal [ "999" ], audit.deactivate_orphans!(ids: [ "999" ])
    assert_equal [ "999" ], client.deactivated
    assert_empty client.deleted
  end

  # Running this with the wrong database (local dev against the production
  # Stream app, say) makes live members look orphaned. Refuse rather than
  # retire people's chat accounts on a bad comparison.
  test "refuses to retire when most Stream users look orphaned" do
    client = FakeClient.new((1..10).map { |n| stream_user("90#{n}") })
    audit = StreamUserAudit.new(client: client)

    error = assert_raises StreamUserAudit::SuspectedMismatch do
      audit.deactivate_orphans!(ids: [ "901" ])
    end
    assert_match(/database/i, error.message)
    assert_empty client.deactivated
  end

  # A high orphan count on its own is not evidence of the wrong database: an
  # app can accumulate stale Stream users legitimately. What distinguishes a
  # mismatch is that our own members are also missing from Stream.
  test "the guard stays quiet when every Conduit user is present in Stream" do
    mine = ours.map { |u| stream_user(u.id, teams: [ u.community.slug ]) }
    stale = (1..20).map { |n| stream_user("90#{n}") }
    client = FakeClient.new(mine + stale)
    audit = StreamUserAudit.new(client: client)

    assert audit.call[:orphaned].size > mine.size, "this fixture should look orphan-heavy"
    assert_equal [ "901" ], audit.deactivate_orphans!(ids: [ "901" ])
  end

  test "the mismatch guard can be overridden deliberately" do
    client = FakeClient.new((1..10).map { |n| stream_user("90#{n}") })
    audit = StreamUserAudit.new(client: client)

    audit.deactivate_orphans!(ids: [ "901" ], force: true)

    assert_equal [ "901" ], client.deactivated
  end

  test "the guard does not fire when only a few users are orphaned" do
    client = FakeClient.new(ours.map { |u| stream_user(u.id, teams: [ u.community.slug ]) } + [ stream_user("999") ])
    audit = StreamUserAudit.new(client: client)

    assert_equal [ "999" ], audit.deactivate_orphans!(ids: [ "999" ])
  end

  test "can hard delete when explicitly asked" do
    client = FakeClient.new(ours.map { |u| stream_user(u.id, teams: [ u.community.slug ]) } + [ stream_user("999") ])

    StreamUserAudit.new(client: client).delete_orphans!(ids: [ "999" ])

    assert_equal [ "999" ], client.deleted
    assert_empty client.deactivated
  end
end
