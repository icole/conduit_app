require "ostruct"

namespace :email do
  desc "Test SMTP connection without sending an email"
  task test_connection: :environment do
    require "net/smtp"

    puts "Testing SMTP connection..."
    puts "Server: mail.privateemail.com:587"
    puts "Username: #{ENV['SMTP_USERNAME']}"

    if ENV["SMTP_USERNAME"].blank? || ENV["SMTP_PASSWORD"].blank?
      puts "\n❌ ERROR: SMTP credentials are not set!"
      puts "Set SMTP_USERNAME and SMTP_PASSWORD environment variables."
      exit 1
    end

    begin
      smtp = Net::SMTP.new("mail.privateemail.com", 587)
      smtp.enable_starttls_auto
      smtp.open_timeout = 10
      smtp.read_timeout = 10
      # Disable SSL verification to work around CRL issues with Namecheap
      context = OpenSSL::SSL::SSLContext.new
      context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      smtp.enable_starttls(context)

      smtp.start("crowwoods.com", ENV["SMTP_USERNAME"], ENV["SMTP_PASSWORD"], :login) do
        puts "\n✅ SMTP connection successful! Credentials are valid."
      end
    rescue Net::SMTPAuthenticationError => e
      puts "\n❌ SMTP Authentication FAILED!"
      puts "Error: #{e.message}"
      puts "\nPossible causes:"
      puts "  - Incorrect username or password"
      puts "  - Account is locked"
      puts "  - 2FA enabled (need app-specific password)"
      exit 1
    rescue StandardError => e
      puts "\n❌ SMTP Connection failed!"
      puts "Error: #{e.class}: #{e.message}"
      exit 1
    end
  end

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
      authentication: :login,
      enable_starttls_auto: true,
      open_timeout: 10,
      read_timeout: 10,
      openssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
    }

    # Use the first community's name if available, fallback to "Conduit"
    community_name = Community.first&.smtp_from_name || "Conduit"
    from_address = "#{community_name} <#{ENV['SMTP_USERNAME']}>"
    puts "Sending test email to #{to_address}..."
    puts "Using SMTP: mail.privateemail.com:587"
    puts "From: #{from_address}"

    begin
      mail = MealMailer.notification_email(
        OpenStruct.new(email: to_address, name: "Test User"),
        "Test Email from Conduit",
        "If you're reading this, email is working!",
        "/meals"
      )
      mail.from = from_address
      mail.deliver_now

      puts "✓ Email sent successfully!"
    rescue => e
      puts "✗ Failed to send email: #{e.message}"
      exit 1
    end
  end
end
