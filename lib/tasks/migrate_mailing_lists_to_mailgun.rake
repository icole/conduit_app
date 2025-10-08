namespace :mailing_lists do
  desc "Migrate existing mailing lists to Mailgun"
  task migrate_to_mailgun: :environment do
    puts "Starting migration of mailing lists to Mailgun..."
    
    mailgun_service = MailgunService.new
    migrated_count = 0
    failed_count = 0
    
    MailingList.active.where(mailgun_list_address: nil).find_each do |mailing_list|
      puts "Migrating mailing list: #{mailing_list.name}"
      
      begin
        # Create the list in Mailgun
        list_address = mailgun_service.create_mailing_list(mailing_list.name, mailing_list.description)
        mailing_list.update_column(:mailgun_list_address, list_address)
        
        # Add all current members to the Mailgun list
        member_count = 0
        mailing_list.users.find_each do |user|
          begin
            mailgun_service.add_member(list_address, user.email, name: user.name)
            member_count += 1
          rescue MailgunService::MailgunError => e
            puts "  Warning: Failed to add member #{user.email}: #{e.message}"
          end
        end
        
        puts "  ✓ Successfully migrated #{mailing_list.name} with #{member_count} members"
        migrated_count += 1
        
      rescue MailgunService::MailgunError => e
        puts "  ✗ Failed to migrate #{mailing_list.name}: #{e.message}"
        failed_count += 1
      rescue => e
        puts "  ✗ Unexpected error migrating #{mailing_list.name}: #{e.message}"
        failed_count += 1
      end
    end
    
    puts "\nMigration completed!"
    puts "Successfully migrated: #{migrated_count} mailing lists"
    puts "Failed to migrate: #{failed_count} mailing lists" if failed_count > 0
    
    if failed_count > 0
      puts "\nPlease check the Mailgun configuration and retry failed migrations."
    end
  end

  desc "Verify Mailgun migration status"
  task verify_migration: :environment do
    puts "Checking migration status..."
    
    total_lists = MailingList.active.count
    migrated_lists = MailingList.active.where.not(mailgun_list_address: nil).count
    pending_lists = total_lists - migrated_lists
    
    puts "Total active mailing lists: #{total_lists}"
    puts "Migrated to Mailgun: #{migrated_lists}"
    puts "Pending migration: #{pending_lists}"
    
    if pending_lists > 0
      puts "\nLists pending migration:"
      MailingList.active.where(mailgun_list_address: nil).pluck(:name).each do |name|
        puts "  - #{name}"
      end
    end
  end

  desc "Remove old ActionMailbox routes after successful migration"
  task cleanup_mailbox_routes: :environment do
    puts "This task would remove ActionMailbox routes."
    puts "The ApplicationMailbox has already been updated to remove mailing list routing."
    puts "Verify your Mailgun webhooks are working before running this in production."
  end
end