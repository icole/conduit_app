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
      role: "admin"
    })

    if StreamChannelService.setup_default_channels(user)
      puts "Default channels created successfully!"
      puts "Channels created: General Discussion, Announcements, Maintenance, Events"
    else
      puts "Failed to create channels. Check logs for details."
    end
  end

  desc "Add all users to default channels"
  task add_users_to_channels: :environment do
    puts "Adding all users to default channels..."

    User.find_each do |user|
      print "Adding #{user.name}... "
      StreamChannelService.ensure_user_in_default_channels(user)
      puts "done"
    end

    puts "All users added to default channels!"
  end

  desc "Fix existing channels and create missing community channels. " \
       "Pass LEGACY_SLUG=slug to assign old unprefixed channels to a specific community."
  task fix_channels: :environment do
    unless StreamChatClient.configured?
      puts "Stream Chat is not configured. Skipping."
      next
    end

    client = StreamChatClient.client

    # Define default channel base IDs (without community prefix)
    default_channel_ids = %w[general announcements maintenance events]

    # Get the legacy slug from environment variable (for assigning old unprefixed channels)
    legacy_slug = ENV["LEGACY_SLUG"]
    if legacy_slug.present?
      puts "Will assign old unprefixed channels to community: #{legacy_slug}"
    else
      puts "No LEGACY_SLUG specified - old unprefixed channels will not be updated"
      puts "Usage: rake stream_chat:fix_channels LEGACY_SLUG=crow-woods"
    end

    Community.find_each do |community|
      puts "\n=== Processing community: #{community.name} (#{community.slug}) ==="

      # Get an admin user for this community to use for API calls
      admin_user = ActsAsTenant.with_tenant(community) do
        User.find_by(admin: true) || User.first
      end

      unless admin_user
        puts "  No users found for community #{community.name}, skipping..."
        next
      end

      puts "  Using user: #{admin_user.name} (ID: #{admin_user.id})"

      # Ensure admin user exists in Stream
      begin
        client.upsert_user({
          id: admin_user.id.to_s,
          name: admin_user.name,
          role: "admin"
        })
      rescue => e
        puts "  Warning: Could not upsert user: #{e.message}"
      end

      # Step 1: Check for OLD unprefixed channels and update them
      # Only process for the specified legacy community
      if legacy_slug.present? && community.slug == legacy_slug
        puts "  Checking for old unprefixed channels (assigning to #{legacy_slug})..."
        default_channel_ids.each do |base_id|
          begin
            old_channel = client.channel("team", channel_id: base_id)

            # Use update_partial which doesn't require created_by
            old_channel.update_partial(
              set: {
                community_id: community.id,
                community_slug: community.slug
              },
              user_id: admin_user.id.to_s
            )
            puts "    Updated #{base_id} with community metadata"
          rescue StreamChat::StreamAPIException => e
            if e.message.include?("Can't find channel")
              puts "    Old channel '#{base_id}' doesn't exist"
            else
              puts "    Warning checking old channel #{base_id}: #{e.message}"
            end
          end
        end
      elsif legacy_slug.present?
        puts "  Skipping old unprefixed channels (only processed for #{legacy_slug})"
      end

      # Step 2: Create NEW prefixed channels for this community
      puts "  Creating/updating prefixed channels..."
      StreamChannelService::DEFAULT_CHANNELS.each do |channel_data|
        channel_id = "#{community.slug}-#{channel_data[:id]}"

        begin
          channel = client.channel("team", channel_id: channel_id)

          # Create the channel with get_or_create semantics
          channel.create(admin_user.id.to_s, {
            name: channel_data[:name],
            description: channel_data[:description],
            community_id: community.id,
            community_slug: community.slug,
            members: [ admin_user.id.to_s ]
          })
          puts "    Created/updated channel: #{channel_id}"

          # Update metadata in case channel already existed
          channel.update_partial(
            set: {
              name: channel_data[:name],
              description: channel_data[:description],
              community_id: community.id,
              community_slug: community.slug
            },
            user_id: admin_user.id.to_s
          )
        rescue => e
          puts "    Error with channel #{channel_id}: #{e.message}"
        end
      end
    end

    puts "\n=== Channel fix complete ==="
  end

  desc "List all Stream Chat channels"
  task list_channels: :environment do
    unless StreamChatClient.configured?
      puts "Stream Chat is not configured."
      next
    end

    client = StreamChatClient.client

    puts "Fetching all team channels..."

    begin
      # Query all team channels
      response = client.query_channels(
        { "type" => { "$eq" => "team" } },
        { "created_at" => -1 },
        limit: 100
      )

      if response["channels"].empty?
        puts "No channels found."
      else
        puts "\nFound #{response['channels'].length} channels:\n"
        response["channels"].each do |channel_data|
          channel = channel_data["channel"]
          puts "  - #{channel['id']}"
          puts "    Name: #{channel['name'] || 'N/A'}"
          puts "    community_slug: #{channel['community_slug'] || 'NOT SET'}"
          puts "    community_id: #{channel['community_id'] || 'NOT SET'}"
          puts "    Members: #{channel_data['members']&.length || 0}"
          puts ""
        end
      end
    rescue => e
      puts "Error fetching channels: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Add all community users to their community's channels"
  task sync_users: :environment do
    unless StreamChatClient.configured?
      puts "Stream Chat is not configured."
      next
    end

    client = StreamChatClient.client

    Community.find_each do |community|
      puts "\n=== Processing community: #{community.name} (#{community.slug}) ==="

      users = ActsAsTenant.with_tenant(community) { User.all.to_a }
      puts "  Found #{users.length} users"

      # Get channel IDs for this community (both prefixed and unprefixed for legacy)
      channel_ids = StreamChannelService::DEFAULT_CHANNELS.map do |ch|
        "#{community.slug}-#{ch[:id]}"
      end

      # Also check for unprefixed channels (for crow-woods legacy)
      channel_ids += StreamChannelService::DEFAULT_CHANNELS.map { |ch| ch[:id] }

      channel_ids.each do |channel_id|
        begin
          channel = client.channel("team", channel_id: channel_id)

          # Verify channel exists using an admin user
          admin_user = users.find(&:admin?) || users.first
          next unless admin_user

          channel.query(user_id: admin_user.id.to_s)

          # Check channel's community_slug matches this community
          # (for unprefixed channels, only add users if it's crow-woods or no slug set)

          # Add all users
          user_ids = users.map { |u| u.id.to_s }
          channel.add_members(user_ids)
          puts "  Added #{user_ids.length} users to #{channel_id}"
        rescue StreamChat::StreamAPIException => e
          if e.message.include?("Can't find channel")
            # Channel doesn't exist, skip
          else
            puts "  Error with #{channel_id}: #{e.message}"
          end
        rescue => e
          puts "  Error with #{channel_id}: #{e.message}"
        end
      end
    end

    puts "\n=== Done ==="
  end
end
