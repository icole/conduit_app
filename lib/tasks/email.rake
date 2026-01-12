# frozen_string_literal: true

require "ostruct"

namespace :email do
  desc "Test Resend API connection"
  task test_connection: :environment do
    puts "Testing Resend API connection..."

    api_key = ENV["RESEND_API_KEY"]
    if api_key.blank?
      puts "\n❌ ERROR: RESEND_API_KEY is not set!"
      puts "Set RESEND_API_KEY environment variable."
      exit 1
    end

    puts "API Key: #{api_key[0..7]}...#{api_key[-4..]}"

    begin
      Resend.api_key = api_key
      # Try to list domains to verify the API key works
      response = Resend::Domains.list
      puts "\n✅ Resend API connection successful!"
      puts "Verified domains:"
      if response[:data].any?
        response[:data].each do |domain|
          status = domain[:status] == "verified" ? "✓" : "⏳"
          puts "  #{status} #{domain[:name]} (#{domain[:status]})"
        end
      else
        puts "  (no domains configured yet)"
        puts "\n⚠️  You need to add and verify a domain at https://resend.com/domains"
      end
    rescue StandardError => e
      puts "\n❌ Resend API connection failed!"
      puts "Error: #{e.class}: #{e.message}"
      exit 1
    end
  end

  desc "Send a test email via Resend"
  task :test, [ :to ] => :environment do |t, args|
    to_address = args[:to]

    unless to_address
      puts "Usage: rails email:test[recipient@example.com]"
      exit 1
    end

    api_key = ENV["RESEND_API_KEY"]
    unless api_key
      puts "Error: RESEND_API_KEY must be set"
      exit 1
    end

    Resend.api_key = api_key

    # Get the from address from the first community or use default
    community = ActsAsTenant.without_tenant { Community.first }
    from_name = community&.smtp_from_name || "Conduit"
    from_email = community&.smtp_from_email || "noreply@crowwoods.com"
    from_address = "#{from_name} <#{from_email}>"

    puts "Sending test email to #{to_address}..."
    puts "From: #{from_address}"

    begin
      response = Resend::Emails.send({
        from: from_address,
        to: to_address,
        subject: "Test Email from Conduit",
        html: "<h1>Hello!</h1><p>If you're reading this, Resend email is working!</p>"
      })

      if response[:id]
        puts "\n✅ Email sent successfully!"
        puts "Message ID: #{response[:id]}"
      else
        puts "\n❌ Failed to send email"
        puts response.inspect
        exit 1
      end
    rescue StandardError => e
      puts "\n❌ Failed to send email: #{e.message}"
      exit 1
    end
  end
end
