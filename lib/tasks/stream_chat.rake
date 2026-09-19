namespace :stream_chat do
  # Prints which Stream app the credentials point at and whether teams are
  # enforced. Used by every teams task so you always know what you're touching.
  def print_stream_app_header(backfill)
    info = backfill.app_info
    key = StreamChatClient.api_key.to_s
    puts "Stream app: #{info[:name]}  (API key #{key[0, 6]}…)  multi-tenant: #{info[:multi_tenant_enabled] ? 'ENABLED' : 'off'}"
    puts ""
    info
  end

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
    StreamChatClient.client.upsert_user(user.stream_user_data)

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
        client.upsert_user(admin_user.stream_user_data)
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

            # Use update_partial with positional args (set, unset)
            old_channel.update_partial({
              "community_id" => community.id,
              "community_slug" => community.slug
            })
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
          # Initialize channel with community metadata + team
          custom_data = StreamChannelService.channel_data(
            community,
            name: channel_data[:name],
            description: channel_data[:description],
            members: [ admin_user.id.to_s ]
          )
          channel = client.channel("team", channel_id: channel_id, data: custom_data)

          # Create the channel (this will use custom_data set above)
          channel.create(admin_user.id.to_s)
          puts "    Created/updated channel: #{channel_id}"

          # Ensure metadata is set
          channel.update_partial(
            StreamChannelService.channel_data(community, name: channel_data[:name], description: channel_data[:description])
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
        sort: { "created_at" => -1 },
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

  desc "Fix user-created channels missing community_slug. " \
       "Pass COMMUNITY_SLUG=slug to assign them to a specific community."
  task fix_user_channels: :environment do
    unless StreamChatClient.configured?
      puts "Stream Chat is not configured. Skipping."
      next
    end

    community_slug = ENV["COMMUNITY_SLUG"]
    unless community_slug.present?
      puts "Usage: rake stream_chat:fix_user_channels COMMUNITY_SLUG=your-community-slug"
      puts "This will add community_slug to all channels that are missing it."
      next
    end

    community = Community.find_by(slug: community_slug)
    unless community
      puts "Community with slug '#{community_slug}' not found."
      next
    end

    client = StreamChatClient.client

    puts "Fetching all team channels..."

    begin
      # Query all team channels
      response = client.query_channels(
        { "type" => { "$eq" => "team" } },
        sort: { "created_at" => -1 },
        limit: 100
      )

      channels_fixed = 0
      channels_skipped = 0

      response["channels"].each do |channel_data|
        channel_info = channel_data["channel"]
        channel_id = channel_info["id"]

        if channel_info["community_slug"].present?
          puts "  ✓ #{channel_id} - already has community_slug: #{channel_info['community_slug']}"
          channels_skipped += 1
        else
          puts "  → Fixing #{channel_id}..."
          channel = client.channel("team", channel_id: channel_id)
          channel.update_partial({
            "community_id" => community.id,
            "community_slug" => community.slug
          })
          puts "    Added community_slug: #{community.slug}"
          channels_fixed += 1
        end
      end

      puts "\n=== Summary ==="
      puts "Channels fixed: #{channels_fixed}"
      puts "Channels already OK: #{channels_skipped}"
    rescue => e
      puts "Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Sync all community members to a specific channel. " \
       "Pass CHANNEL_ID=channel-id to sync members."
  task sync_channel_members: :environment do
    unless StreamChatClient.configured?
      puts "Stream Chat is not configured. Skipping."
      next
    end

    channel_id = ENV["CHANNEL_ID"]
    unless channel_id.present?
      puts "Usage: rake stream_chat:sync_channel_members CHANNEL_ID=pets-1768001867"
      puts "This will add all community members to the specified channel."
      next
    end

    client = StreamChatClient.client

    begin
      # Query the channel to get its community_slug
      channel = client.channel("team", channel_id: channel_id)

      # Use first admin user to query (without tenant scope)
      admin_user = ActsAsTenant.without_tenant do
        User.find_by(admin: true) || User.first
      end
      channel_data = channel.query(user_id: admin_user.id.to_s)
      channel_info = channel_data["channel"]

      community_slug = channel_info["community_slug"]
      unless community_slug.present?
        puts "Channel #{channel_id} has no community_slug set. Run fix_user_channels first."
        next
      end

      community = Community.find_by(slug: community_slug)
      unless community
        puts "Community with slug '#{community_slug}' not found."
        next
      end

      puts "Channel: #{channel_id}"
      puts "Community: #{community.name} (#{community_slug})"

      # Get all users from the community (within tenant scope)
      community_user_ids = ActsAsTenant.with_tenant(community) do
        User.pluck(:id).map(&:to_s)
      end
      puts "Adding #{community_user_ids.length} members..."

      channel.add_members(community_user_ids)

      puts "Successfully added all community members to channel!"
    rescue => e
      puts "Error: #{e.message}"
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

  desc "Add all community members to ALL channels in their community (with confirmation)"
  task sync_all_channels: :environment do
    unless StreamChatClient.configured?
      puts "Stream Chat is not configured."
      next
    end

    client = StreamChatClient.client

    Community.find_each do |community|
      puts "\n=== Community: #{community.name} (#{community.slug}) ==="

      users = ActsAsTenant.with_tenant(community) { User.all.to_a }
      user_ids = users.map { |u| u.id.to_s }
      puts "  Members (#{users.length}): #{users.map(&:name).join(', ')}"

      # Query all channels for this community
      response = client.query_channels(
        {
          "type" => { "$eq" => "team" },
          "community_slug" => { "$eq" => community.slug }
        },
        sort: { "created_at" => -1 },
        limit: 100
      )

      channels = response["channels"]
      if channels.empty?
        puts "  No channels found for this community."
        next
      end

      # Build a diff of missing members per channel
      channels_to_update = {}
      channels.each do |channel_data|
        ch = channel_data["channel"]
        existing_member_ids = (channel_data["members"] || []).map { |m| m["user_id"] }
        missing_ids = user_ids - existing_member_ids
        missing_names = missing_ids.map { |id| users.find { |u| u.id.to_s == id }&.name }.compact

        if missing_ids.any?
          channels_to_update[ch["id"]] = { missing_ids: missing_ids, missing_names: missing_names, name: ch["name"] }
        end
      end

      if channels_to_update.empty?
        puts "  All members are already in all channels!"
        next
      end

      puts "\n  Missing members:"
      channels_to_update.each do |channel_id, info|
        puts "    - #{channel_id} (#{info[:name] || 'unnamed'}) — add: #{info[:missing_names].join(', ')}"
      end

      if ENV["CONFIRM"] == "yes"
        confirm = "y"
      else
        print "\n  Proceed? [y/N] "
        confirm = $stdin.gets&.strip&.downcase
      end
      unless confirm == "y"
        puts "  Skipped."
        next
      end

      # Ensure missing users exist in Stream
      missing_user_ids = channels_to_update.values.flat_map { |info| info[:missing_ids] }.uniq
      missing_user_ids.each do |uid|
        user = users.find { |u| u.id.to_s == uid }
        next unless user
        client.upsert_user(user.stream_user_data)
      end

      channels_to_update.each do |channel_id, info|
        begin
          channel = client.channel("team", channel_id: channel_id)
          channel.add_members(info[:missing_ids])
          puts "    Added #{info[:missing_names].join(', ')} to #{channel_id}"
        rescue => e
          puts "    Error with #{channel_id}: #{e.message}"
        end
      end

      puts "  Done!"
    end

    puts "\n=== All communities processed ==="
  end

  desc "Plan (or with APPLY=true, write) the Stream team for every channel. " \
       "Safe to run before multi-tenant mode is enabled. LEGACY_SLUG=slug assigns old unprefixed default channels."
  task backfill_teams: :environment do
    unless StreamChatClient.configured?
      puts "Stream Chat is not configured."
      next
    end

    backfill = StreamTeamBackfill.new(legacy_slug: ENV["LEGACY_SLUG"])
    info = print_stream_app_header(backfill)
    if info[:multi_tenant_enabled]
      puts "WARNING: multi-tenant mode is already enabled on this app - team changes take effect immediately."
      puts ""
    end

    rows = backfill.plan

    if rows.empty?
      puts "No channels found."
      next
    end

    width = rows.map { |r| r.id.length }.max
    puts format("%-#{width}s  %-18s  %-18s  %-15s  %s", "channel", "current team", "resolved team", "source", "action")
    rows.each do |row|
      action =
        if row.unattributed? then "UNATTRIBUTED"
        elsif row.changed? then "set team"
        else "ok"
        end
      puts format("%-#{width}s  %-18s  %-18s  %-15s  %s", row.id, row.current_team || "-", row.resolved_team || "-", row.source || "-", action)
    end

    puts ""
    puts "#{rows.count(&:changed?)} to update, #{rows.count { |r| !r.changed? && !r.unattributed? }} already correct, " \
         "#{rows.count(&:unattributed?)} unattributed"

    if rows.any?(&:unattributed?)
      puts "Unattributed channels must be assigned (set community_slug) or deleted before applying."
      puts "For old unprefixed default channels, pass LEGACY_SLUG=<slug>."
      next
    end

    if ENV["APPLY"] == "true"
      applied = backfill.apply!
      puts "Updated #{applied.size} channel(s)."
    else
      puts "Dry run. Re-run with APPLY=true to write."
    end
  end

  desc "Verify every channel and every user has a Stream team. Must pass before enabling multi-tenant mode."
  task verify_teams: :environment do
    unless StreamChatClient.configured?
      puts "Stream Chat is not configured."
      next
    end

    backfill = StreamTeamBackfill.new
    print_stream_app_header(backfill)
    report = backfill.verify

    puts "Channels without team:  #{report[:channels_without_team].size}"
    report[:channels_without_team].each { |id| puts "  - #{id}" }
    puts "Channels whose team != community_slug:  #{report[:channels_mismatched].size}"
    report[:channels_mismatched].each { |id| puts "  - #{id}" }
    puts "Users without their community's team:  #{report[:users_without_teams].size}"
    report[:users_without_teams].each { |id| puts "  - user #{id}" }

    if report[:ok] && report[:multi_tenant_enabled]
      puts "\nOK - multi-tenant mode is enabled and every channel and user is assigned to a team."
    elsif report[:ok]
      puts "\nOK - safe to enable multi-tenant mode: bin/rails stream_chat:enable_multi_tenant CONFIRM=true"
    elsif report[:multi_tenant_enabled]
      puts "\nPROBLEM - multi-tenant mode is ENABLED but the items above are unassigned, so those users/channels are"
      puts "currently invisible. Fix them now (stream:sync_users, stream_chat:backfill_teams APPLY=true) or disable"
      puts "multi-tenant mode: bin/rails stream_chat:disable_multi_tenant CONFIRM=true"
      exit 1
    else
      puts "\nNOT READY - run stream:sync_users and stream_chat:backfill_teams APPLY=true, then re-verify."
      exit 1
    end
  end

  desc "Enable Stream multi-tenant (Teams) enforcement. Refuses unless verify_teams passes. Requires CONFIRM=true."
  task enable_multi_tenant: :environment do
    unless StreamChatClient.configured?
      puts "Stream Chat is not configured."
      next
    end

    backfill = StreamTeamBackfill.new
    info = print_stream_app_header(backfill)

    if info[:multi_tenant_enabled]
      puts "Multi-tenant mode is already enabled. Nothing to do."
      next
    end

    unless ENV["CONFIRM"] == "true"
      puts "This makes Stream enforce team isolation for every user and channel on the app above."
      puts "Run stream_chat:verify_teams first, then re-run with CONFIRM=true."
      next
    end

    begin
      backfill.enable_multi_tenant!
    rescue StreamTeamBackfill::NotReady => e
      puts "Refused: #{e.message} (bin/rails stream_chat:verify_teams)"
      exit 1
    end

    puts "Multi-tenant mode is now: #{backfill.app_info[:multi_tenant_enabled] ? 'ENABLED' : 'off (?!)'}"
    puts "Smoke-test from the apps now. Rollback: bin/rails stream_chat:disable_multi_tenant CONFIRM=true"
  end

  desc "Disable Stream multi-tenant enforcement (rollback). Removes all team isolation. Requires CONFIRM=true."
  task disable_multi_tenant: :environment do
    unless StreamChatClient.configured?
      puts "Stream Chat is not configured."
      next
    end

    backfill = StreamTeamBackfill.new
    info = print_stream_app_header(backfill)

    unless info[:multi_tenant_enabled]
      puts "Multi-tenant mode is already off. Nothing to do."
      next
    end

    unless ENV["CONFIRM"] == "true"
      puts "This turns off team checking: every user could access every community's channels."
      puts "Re-run with CONFIRM=true only as a rollback."
      next
    end

    StreamChatClient.client.update_app_settings(multi_tenant_enabled: false)
    puts "Multi-tenant mode is now: #{backfill.app_info[:multi_tenant_enabled] ? 'ENABLED (?!)' : 'off'}"
  end
end
