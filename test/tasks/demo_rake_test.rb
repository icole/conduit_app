require "test_helper"
require "rake"

class DemoRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    ActsAsTenant.current_tenant = nil
  end

  test "demo:create builds a demo community with the sample task data, without printing the password" do
    ENV["DEMO_COMMUNITY_SLUG"] = "demo-test"
    ENV["DEMO_COMMUNITY_DOMAIN"] = "demo-test.example.com"
    ENV["DEMO_USER_PASSWORD"] = "a-long-review-password"
    out, = capture_io { Rake::Task["demo:create"].execute }
    assert_match "Demo community ready", out
    assert_no_match "a-long-review-password", out

    community = Community.find_by!(slug: "demo-test")
    ActsAsTenant.with_tenant(community) do
      assert Workstream.exists?(name: "Garbage & Recycling Coordinator")
      demo_user = User.find_by!(email: "demo@conduitcoho.app")
      assert Task.open.assigned_to(demo_user).exists?
      assert_empty Task.where(workstream_id: nil)
    end
  ensure
    %w[DEMO_COMMUNITY_SLUG DEMO_COMMUNITY_DOMAIN DEMO_USER_PASSWORD].each { |key| ENV.delete(key) }
  end

  test "demo:create refuses to run without a password" do
    ENV.delete("DEMO_USER_PASSWORD")
    assert_raises(ArgumentError) { capture_io { Rake::Task["demo:create"].execute } }
  end

  test "demo:destroy removes only the demo community's task data" do
    ENV["DEMO_COMMUNITY_SLUG"] = "demo-test"
    ENV["DEMO_COMMUNITY_DOMAIN"] = "demo-test.example.com"
    ENV["DEMO_USER_PASSWORD"] = "a-long-review-password"
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
    %w[DEMO_COMMUNITY_SLUG DEMO_COMMUNITY_DOMAIN DEMO_USER_PASSWORD CONFIRM].each { |key| ENV.delete(key) }
  end
end
