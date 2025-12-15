namespace :email do
  desc "Send a test email to verify SMTP configuration"
  task :test, [ :to ] => :environment do |t, args|
    to_address = args[:to] || ENV["SMTP_USERNAME"]

    unless to_address
      puts "Usage: rails email:test[recipient@example.com]"
      puts "   or: SMTP_USERNAME=you@example.com rails email:test"
      exit 1
    end

    unless ENV["SMTP_USERNAME"] && ENV["SMTP_PASSWORD"]
      puts "Error: SMTP_USERNAME and SMTP_PASSWORD must be set"
      puts "Example: SMTP_USERNAME=info@crowwoods.com SMTP_PASSWORD=xxx rails email:test"
      exit 1
    end

    # Configure SMTP for this task
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = {
      address: "mail.privateemail.com",
      port: 587,
      domain: "crowwoods.com",
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: :plain,
      enable_starttls_auto: true
    }

    puts "Sending test email to #{to_address}..."
    puts "Using SMTP: mail.privateemail.com:587"
    puts "From: #{ENV['SMTP_USERNAME']}"

    begin
      MealMailer.notification_email(
        OpenStruct.new(email: to_address, name: "Test User"),
        "Test Email from Conduit",
        "If you're reading this, email is working!",
        "/meals"
      ).deliver_now

      puts "✓ Email sent successfully!"
    rescue => e
      puts "✗ Failed to send email: #{e.message}"
      exit 1
    end
  end
end
