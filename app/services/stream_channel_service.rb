# Service to manage Stream Chat channels
class StreamChannelService
  # Base channel definitions (will be prefixed with community slug)
  DEFAULT_CHANNELS = [
    { id: "general", name: "General Discussion", description: "General community discussions" },
    { id: "announcements", name: "Announcements", description: "Important HOA announcements" },
    { id: "maintenance", name: "Maintenance", description: "Building maintenance and issues" },
    { id: "events", name: "Events", description: "Community events and gatherings" },
    { id: "chores", name: "Chores & Coverage", description: "Tasks someone can't get to this time. Grab one from the Available queue." }
  ].freeze

  # Every channel we create or update goes through this so it always carries
  # the community's Stream `team` (enforced once multi-tenant mode is on) and
  # our own community metadata.
  def self.channel_data(community, **attrs)
    {
      team: community.slug,
      community_id: community.id,
      community_slug: community.slug
    }.merge(attrs)
  end

  def self.ensure_user_in_default_channels(user)
    client = StreamChatClient.client
    community = user.community

    DEFAULT_CHANNELS.each do |channel_data|
      begin
        channel_id = community_channel_id(community, channel_data[:id])
        # Pass created_by_id so Stream's GetOrCreate works with server-side auth
        channel = client.channel("team", channel_id: channel_id, data: channel_data(
          community, name: channel_data[:name], created_by_id: user.id.to_s
        ))

        channel.query(user_id: user.id.to_s)
        channel.add_members([ user.id.to_s ])
      rescue StandardError => e
        Rails.logger.warn "Could not add user to channel #{channel_id}: #{e.message}"
      end
    end
  end

  # Generate community-specific channel ID
  def self.community_channel_id(community, base_id)
    "#{community.slug}-#{base_id}"
  end
end
