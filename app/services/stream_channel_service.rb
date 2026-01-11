# Service to manage Stream Chat channels
class StreamChannelService
  # Base channel definitions (will be prefixed with community slug)
  DEFAULT_CHANNELS = [
    { id: "general", name: "General Discussion", description: "General community discussions" },
    { id: "announcements", name: "Announcements", description: "Important HOA announcements" },
    { id: "maintenance", name: "Maintenance", description: "Building maintenance and issues" },
    { id: "events", name: "Events", description: "Community events and gatherings" }
  ].freeze

  def self.setup_default_channels(user)
    client = StreamChatClient.client
    community = user.community

    DEFAULT_CHANNELS.each do |channel_data|
      begin
        # Prefix channel ID with community slug for isolation
        channel_id = community_channel_id(community, channel_data[:id])

        # Create or get the channel
        channel = client.channel("team", channel_id: channel_id)

        # Query the channel first to see if it exists
        channel.query(user_id: user.id.to_s)

        # Update the channel if it already exists
        channel.update({
          name: channel_data[:name],
          description: channel_data[:description],
          community_id: community.id,
          community_slug: community.slug
        })

        # Add user as member
        channel.add_members([ user.id.to_s ])

        Rails.logger.info "Created/updated channel: #{channel_id} (#{channel_data[:name]})"
      rescue StreamChat::StreamAPIException => e
        # Channel might already exist, try to update it
        if e.message.include?("already exists")
          channel.update(
            {
              name: channel_data[:name],
              description: channel_data[:description],
              community_id: community.id,
              community_slug: community.slug
            },
            user_id: user.id.to_s
          )

          # Add user as member if not already
          channel.add_members([ user.id.to_s ])
          Rails.logger.info "Updated channel: #{channel_id}"
        else
          Rails.logger.error "Failed to create channel #{channel_id}: #{e.message}"
        end
      end
    end

    true
  rescue StandardError => e
    Rails.logger.error "Failed to setup channels: #{e.message}"
    false
  end

  def self.ensure_user_in_default_channels(user)
    client = StreamChatClient.client
    community = user.community

    DEFAULT_CHANNELS.each do |channel_data|
      begin
        channel_id = community_channel_id(community, channel_data[:id])
        channel = client.channel("team", channel_id: channel_id)

        # Try to query the channel first
        begin
          channel.query(user_id: user.id.to_s)
          # Channel exists, just add the user
          channel.add_members([ user.id.to_s ])
        rescue StreamChat::StreamAPIException => e
          if e.message.include?("Can't find channel")
            # Channel doesn't exist, create it
            Rails.logger.info "Creating channel #{channel_id} for community #{community.slug}"
            channel.create(user.id.to_s, {
              name: channel_data[:name],
              description: channel_data[:description],
              community_id: community.id,
              community_slug: community.slug,
              members: [ user.id.to_s ]
            })
          else
            raise e
          end
        end
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
