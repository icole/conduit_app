# frozen_string_literal: true

namespace :stream do
  desc "Setup default Stream Chat channels for HOA community"
  task setup_channels: :environment do
    if StreamChatClient.configured?
      puts "Setting up Stream Chat channels..."
      StreamChannelService.setup_default_channels
      puts "Stream Chat channels have been configured!"
    else
      puts "Stream Chat is not configured. Please add STREAM_API_KEY and STREAM_API_SECRET to your .env file"
    end
  end

  desc "Sync all users to Stream Chat"
  task sync_users: :environment do
    if StreamChatClient.configured?
      puts "Syncing users to Stream Chat..."
      User.find_each do |user|
        user.sync_to_stream_chat
        puts "Synced user: #{user.name}"
      end
      puts "All users have been synced to Stream Chat!"
    else
      puts "Stream Chat is not configured. Please add STREAM_API_KEY and STREAM_API_SECRET to your .env file"
    end
  end

  desc "Test Stream Chat connection"
  task test: :environment do
    if StreamChatClient.configured?
      begin
        client = StreamChatClient.client
        # Try to get server-side settings as a connection test
        response = client.get_app_settings
        puts "✅ Stream Chat connection successful!"
        puts "App name: #{response['app']['name']}" if response["app"]
      rescue => e
        puts "❌ Stream Chat connection failed: #{e.message}"
      end
    else
      puts "Stream Chat is not configured. Please add STREAM_API_KEY and STREAM_API_SECRET to your .env file"
    end
  end
end
