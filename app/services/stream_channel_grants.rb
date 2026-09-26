# frozen_string_literal: true

# Reads and edits the per-role permission grants on a Stream channel type.
#
# Stream's update_channel_type replaces the entire permission array for every
# role named in the request (and leaves unnamed roles untouched), so changing
# one permission means reading the current list, editing it, and writing the
# whole thing back. Doing that by hand in the dashboard is easy to get wrong -
# a missing entry silently revokes a permission - so it lives here with a
# dry-run plan and tests.
class StreamChannelGrants
  class UnknownRole < StandardError; end

  DEFAULT_CHANNEL_TYPE = "team"

  def initialize(client: StreamChatClient.client, channel_type: DEFAULT_CHANNEL_TYPE)
    @client = client
    @channel_type = channel_type
  end

  def grants
    @grants ||= (@client.get_channel_type(@channel_type)["grants"] || {})
  end

  def roles
    grants.keys.sort
  end

  def for_role(role)
    grants.fetch(role) { raise UnknownRole, "#{@channel_type} has no role #{role.inspect}. Roles: #{roles.join(', ')}" }
  end

  # => { role:, permission:, before:, after:, changed: }
  def plan_revoke(role:, permission:)
    before = for_role(role)
    plan(role, permission, before, before - [ permission ])
  end

  def plan_grant(role:, permission:)
    before = for_role(role)
    after = before.include?(permission) ? before : before + [ permission ]
    plan(role, permission, before, after)
  end

  # Returns false when nothing needed changing.
  def revoke!(role:, permission:)
    apply(plan_revoke(role: role, permission: permission))
  end

  def grant!(role:, permission:)
    apply(plan_grant(role: role, permission: permission))
  end

  private

  def plan(role, permission, before, after)
    { role: role, permission: permission, before: before, after: after, changed: before != after }
  end

  def apply(plan)
    return false unless plan[:changed]

    # Only this role is sent, so no other role's grants can be disturbed.
    @client.update_channel_type(@channel_type, grants: { plan[:role] => plan[:after] })
    @grants = nil
    true
  end
end
