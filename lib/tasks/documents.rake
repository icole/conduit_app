# frozen_string_literal: true

namespace :documents do
  desc "Import Google Drive documents as native documents with HTML content"
  task import_from_drive: :environment do
    communities = if ENV["COMMUNITY_SLUG"].present?
      Community.where(slug: ENV["COMMUNITY_SLUG"])
    else
      Community.all
    end

    if communities.empty?
      puts "No communities found."
      next
    end

    communities.find_each do |community|
      puts "\n=== #{community.name} ==="

      ActsAsTenant.with_tenant(community) do
        service = GoogleDriveNativeImportService.new(community)
        result = service.import!

        if result[:success]
          puts result[:message]
          if result[:errors]&.any?
            puts "\nErrors:"
            result[:errors].each { |e| puts "  - #{e}" }
          end
        else
          puts "FAILED: #{result[:message]}"
        end
      end
    end

    puts "\nDone."
  end
end
