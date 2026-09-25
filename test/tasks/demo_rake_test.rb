require "test_helper"
require "rake"

class DemoRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    ActsAsTenant.current_tenant = nil
  end

  test "demo:create builds a demo community with the sample task data" do
    ENV["DEMO_COMMUNITY_SLUG"] = "demo-test"
    ENV["DEMO_COMMUNITY_DOMAIN"] = "demo-test.example.com"
    assert_output(/Demo community created successfully/) { Rake::Task["demo:create"].execute }

    community = Community.find_by!(slug: "demo-test")
    ActsAsTenant.with_tenant(community) do
      assert Workstream.exists?(name: "Garbage & Recycling Coordinator")
      demo_user = User.find_by!(email: "demo@conduitcoho.app")
      assert Task.open.where(assigned_to_user: demo_user).exists?
      assert_empty Task.where(workstream_id: nil)
    end
  ensure
    ENV.delete("DEMO_COMMUNITY_SLUG")
    ENV.delete("DEMO_COMMUNITY_DOMAIN")
  end

  test "demo:destroy removes only the demo community's task data" do
    ENV["DEMO_COMMUNITY_SLUG"] = "demo-test"
    ENV["DEMO_COMMUNITY_DOMAIN"] = "demo-test.example.com"
    capture_io { Rake::Task["demo:create"].execute }
    other_tasks = ActsAsTenant.without_tenant { Task.where.not(community: Community.find_by!(slug: "demo-test")).count }
    other_workstreams = ActsAsTenant.without_tenant { Workstream.where.not(community: Community.find_by!(slug: "demo-test")).count }

    ENV["CONFIRM"] = "true"
    capture_io { Rake::Task["demo:destroy"].execute }

    assert_nil Community.find_by(slug: "demo-test")
    ActsAsTenant.without_tenant do
      assert_equal other_tasks, Task.count
      assert_equal other_workstreams, Workstream.count
    end
  ensure
    %w[DEMO_COMMUNITY_SLUG DEMO_COMMUNITY_DOMAIN CONFIRM].each { |key| ENV.delete(key) }
  end
end
