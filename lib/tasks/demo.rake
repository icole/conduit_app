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
          title: "Welcome Post #{i + 1}",
          user: user
        ) do |post|
          post.content = "This is a sample post for the demo community. Feel free to explore the app!"
        end
      end
      puts "  Created sample posts"

      # Sample meals (upcoming)
      3.times do |i|
        date = Date.today + (i + 1).weeks
        Meal.find_or_create_by!(
          date: date,
          community: community
        ) do |meal|
          meal.title = "Community Dinner"
          meal.chef = user
          meal.description = "A delicious community meal"
        end
      end
      puts "  Created sample meals"

      # Sample tasks
      3.times do |i|
        Task.find_or_create_by!(
          name: "Sample Task #{i + 1}",
          community: community
        ) do |task|
          task.description = "This is a sample task for demonstration"
          task.due_date = Date.today + (i + 1).weeks
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

    community = Community.find_by(slug: community_slug)

    if community.nil?
      puts "Demo community not found (slug: #{community_slug})"
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

    # Delete the community itself
    puts "  Deleting community..."
    community.destroy!

    puts ""
    puts "Demo community destroyed successfully!"
  end

  desc "Reset demo community (destroy and recreate)"
  task reset: :environment do
    Rake::Task["demo:destroy"].invoke
    Rake::Task["demo:create"].invoke
  end
end
