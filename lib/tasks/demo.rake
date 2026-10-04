# frozen_string_literal: true

namespace :demo do
  # The reviewer password comes from DEMO_USER_PASSWORD; there's no default,
  # since this repository is public
  def demo_community
    DemoCommunity.new(
      password: ENV["DEMO_USER_PASSWORD"],
      slug: ENV.fetch("DEMO_COMMUNITY_SLUG", DemoCommunity::SLUG),
      domain: ENV.fetch("DEMO_COMMUNITY_DOMAIN", DemoCommunity::DOMAIN),
      name: ENV.fetch("DEMO_COMMUNITY_NAME", DemoCommunity::NAME)
    )
  end

  desc "Create the App Store / Play reviewers' demo community, or update it. Needs DEMO_USER_PASSWORD."
  task create: :environment do
    community = demo_community.ensure!
    puts "Demo community ready: #{community.name} (#{community.domain})"
    puts "Sign in as #{DemoCommunity::EMAIL} with DEMO_USER_PASSWORD."
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
      puts "  Deleting meals..."
      Meal.destroy_all

      puts "  Deleting tasks..."
      # with_discarded, not unscoped: unscoped would drop the tenant scope too
      TaskAssignment.delete_all
      RecurringTaskResponsible.delete_all
      Task.with_discarded.delete_all
      RecurringTask.with_discarded.delete_all
      WorkstreamOwner.delete_all
      Workstream.delete_all

      puts "  Deleting users..."
      User.destroy_all
      Household.delete_all
    end

    # Delete the community itself (outside tenant scope)
    puts "  Deleting community..."
    ActsAsTenant.without_tenant do
      community.destroy!
    end

    puts ""
    puts "Demo community destroyed successfully!"
  end

  desc "Clear what reviewers added to the demo community and restore the sample content (weekly: DemoResetJob). Needs DEMO_USER_PASSWORD."
  task reset: :environment do
    community = demo_community.reset!
    puts "Demo community reset: #{community.name} (#{community.domain})"
  end
end
