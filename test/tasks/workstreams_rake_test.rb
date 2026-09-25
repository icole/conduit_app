require "test_helper"
require "rake"

class WorkstreamsRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @file = Rails.root.join("tmp/workstreams_rake_test.yml")
    File.write(@file, { "workstreams" => [ { "name" => "Garden Health", "type" => "permanent", "priority" => "important",
                                             "description" => "Keeps the landscaping healthy.", "owners" => [ "Jane" ] } ] }.to_yaml)
    ActsAsTenant.current_tenant = nil
  end

  teardown do
    File.delete(@file) if File.exist?(@file)
    %w[SLUG FILE DRY_RUN].each { |key| ENV.delete(key) }
  end

  def run_import(**env)
    env.each { |key, value| ENV[key.to_s] = value }
    Rake::Task["workstreams:import"].reenable
    capture_io { Rake::Task["workstreams:import"].invoke }.first
  end

  def garden_health = ActsAsTenant.with_tenant(communities(:crow_woods)) { Workstream.find_by(name: "Garden Health") }

  test "DRY_RUN lists the changes without making them" do
    out = run_import(SLUG: "crow-woods", FILE: @file.to_s, DRY_RUN: "true")
    assert_match "create workstream Garden Health", out
    assert_match "Dry run", out
    assert_nil garden_health
  end

  test "without DRY_RUN it applies the plan" do
    out = run_import(SLUG: "crow-woods", FILE: @file.to_s)
    assert_match "Applied 2 changes", out
    assert_equal [ "Jane Smith" ], garden_health.owners.map(&:name)
  end
end
