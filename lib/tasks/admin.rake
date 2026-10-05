namespace :admin do
  desc "Make an admin in a community. COMMUNITY_SLUG, ADMIN_NAME, ADMIN_EMAIL and ADMIN_PASSWORD are required."
  task create: :environment do
    slug, name, email, password = ENV.values_at("COMMUNITY_SLUG", "ADMIN_NAME", "ADMIN_EMAIL", "ADMIN_PASSWORD")

    if [ slug, name, email, password ].any?(&:blank?)
      puts "COMMUNITY_SLUG, ADMIN_NAME, ADMIN_EMAIL and ADMIN_PASSWORD are required."
      puts "  COMMUNITY_SLUG=willow-creek ADMIN_NAME='Your Name' ADMIN_EMAIL=you@example.com ADMIN_PASSWORD=... bin/rails admin:create"
      exit 1
    end

    community = Community.find_by(slug: slug)
    unless community
      puts "No community with the slug '#{slug}'. Communities are created by signing up (/communities/new)."
      exit 1
    end

    ActsAsTenant.with_tenant(community) do
      if User.exists?(email: email.downcase)
        puts "#{email} is already a member of #{community.name}."
        exit 0
      end

      user = User.new(name: name, email: email.downcase, password: password, admin: true, email_verified_at: Time.current)
      if user.save
        puts "Made #{email} an admin of #{community.name}."
      else
        puts "Couldn't create the admin: #{user.errors.full_messages.join(', ')}"
        exit 1
      end
    end
  end
end
