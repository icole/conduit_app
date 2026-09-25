# frozen_string_literal: true

namespace :workstreams do
  desc "Apply a workstream plan (YAML) to a community. SLUG=<community slug> FILE=<path> [DRY_RUN=true]"
  task import: :environment do
    community = ActsAsTenant.without_tenant { Community.find_by!(slug: ENV.fetch("SLUG")) }
    data = YAML.safe_load_file(ENV.fetch("FILE"))
    dry_run = ENV["DRY_RUN"] == "true"

    changes = WorkstreamImport.new(community, data).apply!(dry_run: dry_run)
    changes.each { |change| puts "  #{change}" }
    puts dry_run ? "Dry run: #{changes.size} changes would be made to #{community.name}." : "Applied #{changes.size} changes to #{community.name}."
  rescue WorkstreamImport::Error => e
    abort e.message
  end
end
