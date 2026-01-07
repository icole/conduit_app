namespace :admin do
  desc "Create the first admin user (interactive)"
  task create: :environment do
    puts "Creating first admin user..."
    puts

    # Find or create default community
    community = Community.first
    unless community
      puts "No community found. Creating default community..."
      community = Community.find_or_create_by!(slug: "crow-woods") do |c|
        c.name = "Crow Woods"
        c.domain = ENV["PRODUCTION_DOMAIN"] || "conduit.crowwoods.com"
        c.settings = {}
        c.time_zone = "America/New_York"
      end
      puts "Created community: #{community.name}"
    end

    ActsAsTenant.with_tenant(community) do
      if User.where(admin: true).exists?
        print "An admin user already exists. Create another? (y/N): "
        response = $stdin.gets.chomp.downcase
        unless response == "y"
          puts "Aborted."
          exit
        end
      end

      print "Name: "
      name = $stdin.gets.chomp

      print "Email: "
      email = $stdin.gets.chomp

      print "Password (min 6 characters): "
      password = $stdin.gets.chomp

      if name.blank? || email.blank? || password.blank?
        puts "Error: All fields are required."
        exit 1
      end

      user = User.new(
        name: name,
        email: email,
        password: password,
        admin: true
      )

      if user.save
        puts
        puts "Admin user created successfully!"
        puts "  Name:  #{user.name}"
        puts "  Email: #{user.email}"
        puts "  Admin: Yes"
        puts "  Community: #{community.name}"
        puts
        puts "You can now log in at /login"
      else
        puts
        puts "Error creating user:"
        user.errors.full_messages.each do |msg|
          puts "  - #{msg}"
        end
        exit 1
      end
    end
  end

  desc "Create admin user non-interactively (use ADMIN_NAME, ADMIN_EMAIL, ADMIN_PASSWORD env vars)"
  task create_noninteractive: :environment do
    name = ENV["ADMIN_NAME"]
    email = ENV["ADMIN_EMAIL"]
    password = ENV["ADMIN_PASSWORD"]

    if name.blank? || email.blank? || password.blank?
      puts "Error: ADMIN_NAME, ADMIN_EMAIL, and ADMIN_PASSWORD environment variables are required."
      puts
      puts "Usage:"
      puts "  ADMIN_NAME='Your Name' ADMIN_EMAIL='you@example.com' ADMIN_PASSWORD='secret' bin/rails admin:create_noninteractive"
      exit 1
    end

    # Find or create default community
    community = Community.first
    unless community
      puts "No community found. Creating default community..."
      community = Community.find_or_create_by!(slug: "crow-woods") do |c|
        c.name = "Crow Woods"
        c.domain = ENV["PRODUCTION_DOMAIN"] || "conduit.crowwoods.com"
        c.settings = {}
        c.time_zone = "America/New_York"
      end
      puts "Created community: #{community.name}"
    end

    ActsAsTenant.with_tenant(community) do
      if User.exists?(email: email)
        puts "User with email '#{email}' already exists."
        exit 0
      end

      user = User.new(
        name: name,
        email: email,
        password: password,
        admin: true
      )

      if user.save
        puts "Admin user '#{email}' created successfully."
        puts "  Community: #{community.name}"
      else
        puts "Error creating user:"
        user.errors.full_messages.each do |msg|
          puts "  - #{msg}"
        end
        exit 1
      end
    end
  end
end
