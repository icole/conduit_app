# frozen_string_literal: true

# Compares the Stream user list against our own and reports the drift:
# accounts that outlived their Conduit user, members Stream has never seen,
# users on the wrong team, and anyone holding a role above "user".
#
# Deletion is deliberately not automatic - some Stream users exist on purpose
# (a dashboard demo account, for instance) - so the caller names the ids.
class StreamUserAudit
  class NotOrphaned < StandardError; end

  PAGE_SIZE = 100

  # Community admins must stay on Stream's plain "user" role; see CON-49.
  EXPECTED_ROLE = "user"

  def initialize(client: StreamChatClient.client)
    @client = client
  end

  # => { stream_count:, conduit_count:, orphaned:, missing_from_stream:,
  #      wrong_team:, elevated_role:, ok: }
  def call
    orphaned = stream_users.reject { |u| conduit_by_id.key?(u["id"]) }.map { |u| summarize(u) }
    missing = conduit_by_id.keys - stream_users.map { |u| u["id"] }

    wrong_team = []
    elevated = []
    stream_users.each do |u|
      user = conduit_by_id[u["id"]]
      next unless user

      expected = [ user.community.slug ]
      actual = Array(u["teams"])
      wrong_team << summarize(u).merge(expected: expected, actual: actual) if actual.sort != expected.sort
      elevated << summarize(u) if u["role"].to_s != EXPECTED_ROLE
    end

    {
      stream_count: stream_users.size,
      conduit_count: conduit_by_id.size,
      orphaned: orphaned,
      missing_from_stream: missing,
      wrong_team: wrong_team,
      elevated_role: elevated,
      ok: orphaned.empty? && missing.empty? && wrong_team.empty? && elevated.empty?
    }
  end

  # Deactivated users can't connect, send or receive, and it's reversible with
  # reactivate_user. Preferred over deletion: the community keeps the history.
  def deactivate_orphans!(ids:)
    verify_orphaned!(ids)
    ids.each { |id| @client.deactivate_user(id) }
    ids
  end

  # Irreversible. Only for genuine erasure.
  def delete_orphans!(ids:)
    verify_orphaned!(ids)
    ids.each { |id| @client.delete_user(id) }
    ids
  end

  private

  def verify_orphaned!(ids)
    known = orphaned_ids
    unexpected = ids - known
    return if unexpected.empty?

    raise NotOrphaned, "these ids belong to live Conduit accounts or are unknown to Stream: #{unexpected.join(', ')}"
  end

  def orphaned_ids
    stream_users.map { |u| u["id"] } - conduit_by_id.keys
  end

  def summarize(user)
    {
      id: user["id"],
      name: user["name"],
      role: user["role"],
      teams: Array(user["teams"]),
      last_active: user["last_active"]
    }
  end

  def stream_users
    @stream_users ||= @client.query_users({}, limit: PAGE_SIZE)["users"]
  end

  def conduit_by_id
    @conduit_by_id ||= ActsAsTenant.without_tenant { User.unscoped.includes(:community).to_a }
                                   .index_by { |u| u.id.to_s }
  end
end
