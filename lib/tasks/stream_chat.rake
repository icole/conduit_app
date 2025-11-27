namespace :stream_chat do
  desc "Setup default Stream Chat channels for HOA community"
  task setup_channels: :environment do
    puts "Setting up default Stream Chat channels..."

    # Get an admin user or the first user
    user = User.find_by(admin: true) || User.first

    if user.nil?
      puts "No users found. Please create at least one user first."
      exit
    end

    # Sync user to Stream
    StreamChatClient.client.upsert_user({
      id: user.id.to_s,
      name: user.name,
      role: 'admin'
    })

    if StreamChannelService.setup_default_channels(user)
      puts "✅ Default channels created successfully!"
      puts "Channels created: General Discussion, Announcements, Maintenance, Events"
    else
      puts "❌ Failed to create channels. Check logs for details."
    end
  end

  desc "Add all users to default channels"
  task add_users_to_channels: :environment do
    puts "Adding all users to default channels..."

    User.find_each do |user|
      print "Adding #{user.name}... "
      StreamChannelService.ensure_user_in_default_channels(user)
      puts "✓"
    end

    puts "✅ All users added to default channels!"
  end
end