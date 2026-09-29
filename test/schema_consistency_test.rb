require "test_helper"

# db/schema.rb once listed tables no migration creates (roles, time_entries,
# ...), dumped from a dev database that had run an unmerged branch (CON-69).
# Fresh databases load schema.rb, so tests ran against tables production
# never had. Every table in schema.rb must come from a migration.
class SchemaConsistencyTest < ActiveSupport::TestCase
  SCHEMA = ENV.fetch("SCHEMA_FILE", Rails.root.join("db/schema.rb").to_s)

  test "every table in db/schema.rb is created by a migration in db/migrate" do
    tables = File.read(SCHEMA).scan(/create_table "([^"]+)"/).flatten
    migrations = Dir[Rails.root.join("db/migrate/*.rb")].map { |path| File.read(path) }.join("\n")

    orphans = tables.reject { |table| migrations.match?(/create_table[ (]+[:"']#{Regexp.escape(table)}\b/) }
    assert_empty orphans, "Tables in db/schema.rb that no migration creates"
  end
end
