# frozen_string_literal: true

# Compares the Stream user list against our own and reports the drift:
# accounts that outlived their Conduit user, members Stream has never seen,
# users on the wrong team, and anyone holding a role above "user".
#
# Deletion is deliberately not automatic - some Stream users exist on purpose
# (a dashboard demo account, for instance) - so the caller names the ids.
class StreamUserAudit
  class NotOrphaned < StandardError; end
  class SuspectedMismatch < StandardError; end

  # A wrong database shows up two ways at once: lots of Stream users with no
  # Conduit account, *and* Conduit members Stream has never heard of. Either
  # alone is normal - an app accumulates stale users, and a new member has no
  # chat identity until they open chat - so both are required before refusing.
  MAX_ORPHAN_RATIO = 0.3

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
  def deactivate_orphans!(ids:, force: false)
    verify_safe_to_retire!(ids, force)
    ids.each { |id| @client.deactivate_user(id) }
    ids
  end

  # Irreversible. Only for genuine erasure.
  def delete_orphans!(ids:, force: false)
    verify_safe_to_retire!(ids, force)
    ids.each { |id| @client.delete_user(id) }
    ids
  end

  private

  def verify_safe_to_retire!(ids, force)
    verify_environment_matches! unless force
    verify_orphaned!(ids)
  end

  def verify_environment_matches!
    return if stream_users.empty?

    ratio = orphaned_ids.size.to_f / stream_users.size
    return if ratio <= MAX_ORPHAN_RATIO

    # Every one of our members present in Stream means the comparison is sound,
    # however many extra Stream users there are.
    missing = conduit_by_id.keys - stream_users.map { |u| u["id"] }
    return if missing.empty?

    raise SuspectedMismatch,
      "#{orphaned_ids.size} of #{stream_users.size} Stream users have no Conduit account " \
      "(#{(ratio * 100).round}%), and #{missing.size} Conduit user(s) are missing from Stream. " \
      "That combination usually means the database and the Stream app are different " \
      "environments - check which database this is running against. " \
      "Pass force: true only if the list really is that stale."
  end

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
