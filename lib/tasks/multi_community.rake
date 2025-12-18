namespace :multi_community do
  desc "Migrate existing data to multi-community structure"
  task setup: :environment do
    puts "Creating default community..."

    # Step 1: Create default community
    community = Community.find_or_create_by!(slug: "crow-woods") do |c|
      c.name = "Crow Woods"
      c.domain = ENV["PRODUCTION_DOMAIN"] || "conduit.crowwoods.com"
      c.settings = {
        "google_calendar_id" => ENV["GOOGLE_CALENDAR_ID"],
        "google_drive_folder_id" => ENV["GOOGLE_DRIVE_FOLDER_ID"],
        "smtp_username" => ENV["SMTP_USERNAME"]
      }.compact
      c.time_zone = "America/New_York"
    end

    puts "Created/found community: #{community.name} (ID: #{community.id})"
    puts "Domain: #{community.domain}"

    # Step 2: Associate all existing records with this community
    # Use unscoped to bypass acts_as_tenant scoping
    models_to_update = [
      User, Post, Task, Chore, Meal, MealSchedule,
      DiscussionTopic, CalendarEvent, Document, Decision, Invitation
    ]

    puts "\nAssociating existing records with community..."
    models_to_update.each do |model|
      count = model.unscoped.where(community_id: nil).update_all(community_id: community.id)
      puts "  #{model.name}: #{count} records updated"
    end

    puts "\nMigration complete!"
  end

  desc "Create a new community"
  task :create, [ :name, :slug, :domain ] => :environment do |t, args|
    if args[:name].blank? || args[:slug].blank? || args[:domain].blank?
      puts "Usage: bin/rails 'multi_community:create[Community Name,community-slug,community.domain.com]'"
      exit 1
    end

    community = Community.create!(
      name: args[:name],
      slug: args[:slug],
      domain: args[:domain],
      settings: {},
      time_zone: "America/New_York"
    )
    puts "Created community: #{community.name}"
    puts "  Slug: #{community.slug}"
    puts "  Domain: #{community.domain}"
    puts "  ID: #{community.id}"
  end

  desc "Update community domain"
  task :update_domain, [ :slug, :domain ] => :environment do |t, args|
    community = Community.find_by!(slug: args[:slug])
    community.update!(domain: args[:domain])
    puts "Updated #{community.name} domain to: #{community.domain}"
  end

  desc "Create admin user for a community"
  task :create_admin, [ :email, :password, :name ] => :environment do |t, args|
    email = args[:email] || "admin@example.com"
    password = args[:password] || "password123"
    name = args[:name] || "Admin User"

    community = Community.first
    unless community
      puts "Error: No community exists. Run multi_community:setup first."
      exit 1
    end

    ActsAsTenant.with_tenant(community) do
      user = User.find_or_initialize_by(email: email)
      user.name = name
      user.password = password
      user.password_confirmation = password
      user.admin = true
      user.save!
      puts "Admin user created/updated:"
      puts "  Email: #{user.email}"
      puts "  Name: #{user.name}"
      puts "  Admin: #{user.admin}"
      puts "  Community: #{community.name}"
    end
  end

  desc "List all communities"
  task list: :environment do
    communities = Community.all
    if communities.empty?
      puts "No communities found."
    else
      puts "Communities:"
      communities.each do |c|
        puts "  #{c.id}: #{c.name} (#{c.slug}) - #{c.domain}"
      end
    end
  end
end
