# Service to manage Stream Chat channels
class StreamChannelService
  def self.setup_default_channels(user)
    client = StreamChatClient.client

    # Define default HOA channels
    channels = [
      { id: 'general', name: 'General Discussion', description: 'General community discussions' },
      { id: 'announcements', name: 'Announcements', description: 'Important HOA announcements' },
      { id: 'maintenance', name: 'Maintenance', description: 'Building maintenance and issues' },
      { id: 'events', name: 'Events', description: 'Community events and gatherings' }
    ]

    channels.each do |channel_data|
      begin
        # Create or get the channel
        channel = client.channel('team', channel_id: channel_data[:id])

        # Query the channel first to see if it exists
        channel.query(user_id: user.id.to_s)

        # Update the channel if it already exists
        channel.update({
          name: channel_data[:name],
          description: channel_data[:description]
        })

        # Add user as member
        channel.add_members([user.id.to_s])

        Rails.logger.info "Created/updated channel: #{channel_data[:name]}"
      rescue StreamChat::StreamAPIException => e
        # Channel might already exist, try to update it
        if e.message.include?("already exists")
          channel.update(
            {
              name: channel_data[:name],
              description: channel_data[:description]
            },
            user_id: user.id.to_s
          )

          # Add user as member if not already
          channel.add_members([user.id.to_s])
          Rails.logger.info "Updated channel: #{channel_data[:name]}"
        else
          Rails.logger.error "Failed to create channel #{channel_data[:id]}: #{e.message}"
        end
      end
    end

    true
  rescue => e
    Rails.logger.error "Failed to setup channels: #{e.message}"
    false
  end

  def self.ensure_user_in_default_channels(user)
    client = StreamChatClient.client

    %w[general announcements maintenance events].each do |channel_id|
      begin
        channel = client.channel('team', channel_id: channel_id)
        channel.add_members([user.id.to_s])
      rescue => e
        Rails.logger.warn "Could not add user to channel #{channel_id}: #{e.message}"
      end
    end
  end
end