# frozen_string_literal: true

namespace :demo do
  desc "Create a demo community with demo user for App Store review"
  task create: :environment do
    # Demo community settings
    community_name = ENV.fetch("DEMO_COMMUNITY_NAME", "Demo Community")
    community_domain = ENV.fetch("DEMO_COMMUNITY_DOMAIN", "demo.conduitcoho.app")
    community_slug = ENV.fetch("DEMO_COMMUNITY_SLUG", "demo")

    # Demo user settings
    demo_email = ENV.fetch("DEMO_USER_EMAIL", "demo@conduitcoho.app")
    demo_password = ENV.fetch("DEMO_USER_PASSWORD", "DemoPass123!")
    demo_name = ENV.fetch("DEMO_USER_NAME", "Demo User")

    puts "Creating demo community..."

    # Create or find the demo community
    community = Community.find_or_initialize_by(slug: community_slug)
    community.assign_attributes(
      name: community_name,
      domain: community_domain
    )

    if community.save
      puts "  Community: #{community.name} (#{community.domain})"
    else
      puts "  ERROR: #{community.errors.full_messages.join(', ')}"
      exit 1
    end

    # Create the demo user within the community tenant
    ActsAsTenant.with_tenant(community) do
      puts "Creating demo user..."

      user = User.find_or_initialize_by(email: demo_email)
      user.assign_attributes(
        name: demo_name,
        password: demo_password,
        password_confirmation: demo_password,
        community: community
      )

      if user.save
        puts "  User: #{user.email}"
        puts "  Password: #{demo_password}"
      else
        puts "  ERROR: #{user.errors.full_messages.join(', ')}"
        exit 1
      end

      # Create some sample data for the demo
      puts "Creating sample data..."

      # Sample posts
      3.times do |i|
        Post.find_or_create_by!(
          content: "Welcome to the demo community! This is sample post #{i + 1}. Feel free to explore the app!",
          user: user
        )
      end
      puts "  Created sample posts"

      # Sample meals (upcoming)
      3.times do |i|
        scheduled_at = (Date.today + (i + 1).weeks).to_datetime.change(hour: 18)
        Meal.find_or_create_by!(
          scheduled_at: scheduled_at,
          community: community
        ) do |meal|
          meal.title = "Community Dinner #{i + 1}"
          meal.description = "A delicious community meal for everyone to enjoy"
          meal.rsvp_deadline = scheduled_at - 1.day
        end
      end
      puts "  Created sample meals"

      # Sample tasks
      3.times do |i|
        Task.find_or_create_by!(
          title: "Sample Task #{i + 1}",
          community: community
        ) do |task|
          task.description = "This is a sample task for demonstration"
          task.due_date = Date.today + (i + 1).weeks
          task.user = user
          task.status = "backlog"
        end
      end
      puts "  Created sample tasks"
    end

    puts ""
    puts "=" * 50
    puts "Demo community created successfully!"
    puts "=" * 50
    puts ""
    puts "Community: #{community_name}"
    puts "Domain: #{community_domain}"
    puts ""
    puts "Login credentials:"
    puts "  Email: #{demo_email}"
    puts "  Password: #{demo_password}"
    puts ""
    puts "Add '#{community_domain}' to your proxy hosts if needed."
    puts "=" * 50
  end

  desc "Destroy the demo community and all its data"
  task destroy: :environment do
    community_slug = ENV.fetch("DEMO_COMMUNITY_SLUG", "demo")

    # Safety check: prevent accidentally destroying production communities
    protected_slugs = %w[crow-woods crowwoods production prod main]
    if protected_slugs.include?(community_slug.downcase)
      puts "ERROR: Cannot destroy protected community '#{community_slug}'"
      puts "This task is only for demo/test communities."
      exit 1
    end

    community = Community.find_by(slug: community_slug)

    if community.nil?
      puts "Demo community not found (slug: #{community_slug})"
      exit 0
    end

    # Safety check: ensure this looks like a demo community
    unless community.domain.include?("demo") || community.name.downcase.include?("demo")
      puts "ERROR: Community '#{community.name}' (#{community.domain}) does not appear to be a demo community."
      puts "Domain or name must contain 'demo' to be destroyed with this task."
      puts "If you really want to destroy this community, do it manually in the Rails console."
      exit 1
    end

    puts ""
    puts "=" * 50
    puts "WARNING: This will permanently delete:"
    puts "  Community: #{community.name}"
    puts "  Domain: #{community.domain}"
    puts "  Slug: #{community.slug}"

    ActsAsTenant.with_tenant(community) do
      puts "  Users: #{User.count}"
      puts "  Posts: #{Post.count}"
      puts "  Meals: #{Meal.count}"
      puts "  Tasks: #{Task.count}"
    end

    puts "=" * 50
    puts ""

    # Require explicit confirmation unless CONFIRM=true
    unless ENV["CONFIRM"] == "true"
      puts "To proceed, run with CONFIRM=true:"
      puts "  CONFIRM=true bin/rails demo:destroy"
      exit 0
    end

    puts "Destroying demo community: #{community.name}..."

    ActsAsTenant.with_tenant(community) do
      # Delete all associated data
      puts "  Deleting posts..."
      Post.destroy_all

      puts "  Deleting meals..."
      Meal.destroy_all

      puts "  Deleting tasks..."
      Task.destroy_all

      puts "  Deleting users..."
      User.destroy_all
    end

    # Delete the community itself (outside tenant scope)
    puts "  Deleting community..."
    ActsAsTenant.without_tenant do
      community.destroy!
    end

    puts ""
    puts "Demo community destroyed successfully!"
  end

  desc "Reset demo community (destroy and recreate)"
  task reset: :environment do
    Rake::Task["demo:destroy"].invoke
    Rake::Task["demo:create"].invoke
  end
end
