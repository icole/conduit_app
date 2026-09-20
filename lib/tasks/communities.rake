# frozen_string_literal: true

# Manual community lifecycle management. Self-created communities start
# `pending`; approving one is what unlocks the metered features (Stream chat,
# Liveblocks), so this is also the lever on third-party usage.
namespace :communities do
  desc "List communities with status and member count"
  task list: :environment do
    Community.order(:created_at).each do |c|
      members = ActsAsTenant.with_tenant(c) { User.count }
      puts format("%-25s %-10s %3d members  %s", c.slug, c.status, members, c.created_at.to_date)
    end
  end

  desc "Approve a pending community and email its admins. SLUG=community-slug"
  task approve: :environment do
    community = Community.find_by!(slug: ENV.fetch("SLUG"))
    if community.active?
      puts "#{community.slug} is already active."
      next
    end

    community.approve!
    puts "#{community.slug}: #{community.status}. Admins have been emailed."
  end

  desc "Suspend a community: members lose access and every mobile token is revoked. SLUG=community-slug CONFIRM=true"
  task suspend: :environment do
    community = Community.find_by!(slug: ENV.fetch("SLUG"))
    unless ENV["CONFIRM"] == "true"
      puts "This locks #{community.name} out of the app entirely. Re-run with CONFIRM=true."
      next
    end

    community.suspend!
    puts "#{community.slug}: #{community.status}. Mobile tokens revoked."
  end
end
