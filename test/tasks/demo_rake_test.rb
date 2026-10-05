require "test_helper"
require "rake"
require "minitest/mock"
require_relative "../support/fake_stream_client"

class DemoRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    ActsAsTenant.current_tenant = nil
  end

  # The demo posts in chat, so it always runs against the fake Stream client
  def run_task(name)
    StreamChatClient.stub(:configured?, true) do
      StreamChatClient.stub(:client, FakeStreamClient.new) { Rake::Task[name].execute }
    end
  end

  test "demo:create builds a demo community with the sample task data, without printing the password" do
    ENV["DEMO_COMMUNITY_SLUG"] = "demo-test"
    ENV["DEMO_COMMUNITY_DOMAIN"] = "demo-test.example.com"
    password = SecureRandom.base58(20)
    ENV["DEMO_USER_PASSWORD"] = password
    out, = capture_io { run_task("demo:create") }
    assert_match "Demo community ready", out
    assert_no_match password, out

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
    assert_raises(ArgumentError) { capture_io { run_task("demo:create") } }
  end

  test "demo:destroy removes only the demo community's task data" do
    ENV["DEMO_COMMUNITY_SLUG"] = "demo-test"
    ENV["DEMO_COMMUNITY_DOMAIN"] = "demo-test.example.com"
    ENV["DEMO_USER_PASSWORD"] = SecureRandom.base58(20)
    capture_io { run_task("demo:create") }
    other_tasks = ActsAsTenant.without_tenant { Task.where.not(community: Community.find_by!(slug: "demo-test")).count }
    other_workstreams = ActsAsTenant.without_tenant { Workstream.where.not(community: Community.find_by!(slug: "demo-test")).count }

    ENV["CONFIRM"] = "true"
    capture_io { run_task("demo:destroy") }

    assert_nil Community.find_by(slug: "demo-test")
    ActsAsTenant.without_tenant do
      assert_equal other_tasks, Task.count
      assert_equal other_workstreams, Workstream.count
    end
  ensure
    %w[DEMO_COMMUNITY_SLUG DEMO_COMMUNITY_DOMAIN DEMO_USER_PASSWORD CONFIRM].each { |key| ENV.delete(key) }
  end
end
