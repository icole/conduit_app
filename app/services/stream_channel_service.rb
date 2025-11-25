# frozen_string_literal: true

# Service to manage Stream Chat channels for the HOA community
class StreamChannelService
  DEFAULT_CHANNELS = [
    { id: 'general', name: 'General Chat', description: 'General community discussions' },
    { id: 'building-a', name: 'Building A', description: 'Building A residents' },
    { id: 'building-b', name: 'Building B', description: 'Building B residents' },
    { id: 'pool', name: 'Pool Area', description: 'Pool schedules and rules' },
    { id: 'maintenance', name: 'Maintenance', description: 'Maintenance requests and updates' },
    { id: 'announcements', name: 'Announcements', description: 'Official HOA announcements', read_only: true },
    { id: 'board', name: 'HOA Board', description: 'Board member discussions', private: true }
  ].freeze

  class << self
    def setup_default_channels
      return unless StreamChatClient.configured?

      client = StreamChatClient.client

      # Get or create an admin user for channel creation
      admin_user = get_admin_user
      return unless admin_user

      DEFAULT_CHANNELS.each do |channel_config|
        create_or_update_channel(client, channel_config, admin_user)
      rescue => e
        Rails.logger.error "Failed to create channel #{channel_config[:id]}: #{e.message}"
      end
    end

    private

    def get_admin_user
      # Find an admin user or create a system user
      admin = User.find_by(admin: true) || User.first
      return nil unless admin

      # Sync admin to Stream
      admin.sync_to_stream_chat
      admin
    rescue => e
      Rails.logger.error "Failed to get admin user for channel creation: #{e.message}"
      nil
    end

    def create_or_update_channel(client, config, admin_user)
      channel_type = config[:read_only] ? 'livestream' : 'team'

      # Prepare channel data
      channel_data = {
        name: config[:name],
        description: config[:description],
        created_by: admin_user.stream_user_id
      }

      # Create or get the channel
      channel = client.channel(channel_type, config[:id])

      # Create or update the channel
      response = channel.create(admin_user.stream_user_id, members: [admin_user.stream_user_id], **channel_data)

      Rails.logger.info "Created/Updated channel: #{config[:name]} (#{config[:id]})"

      # Add all users to public channels (except board channel)
      unless config[:private]
        add_all_users_to_channel(channel)
      else
        # For private channels, only add admin users
        add_admin_users_to_channel(channel)
      end
    rescue => e
      Rails.logger.error "Error setting up channel #{config[:id]}: #{e.message}"
    end

    def add_all_users_to_channel(channel)
      User.find_each do |user|
        user.sync_to_stream_chat
        channel.add_members([user.stream_user_id])
      rescue => e
        Rails.logger.warn "Could not add user #{user.id} to channel: #{e.message}"
      end
    end

    def add_admin_users_to_channel(channel)
      User.where(admin: true).find_each do |user|
        user.sync_to_stream_chat
        channel.add_members([user.stream_user_id])
      rescue => e
        Rails.logger.warn "Could not add admin user #{user.id} to channel: #{e.message}"
      end
    end
  end
end