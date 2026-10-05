require "test_helper"
require "rake"

# Making a community admin from the command line, e.g. on a fresh install.
# It used to pick Community.first, which in a multi-community app is a guess.
class AdminRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    ActsAsTenant.current_tenant = nil
    @password = SecureRandom.base58(16)
  end

  teardown { %w[COMMUNITY_SLUG ADMIN_NAME ADMIN_EMAIL ADMIN_PASSWORD].each { |key| ENV.delete(key) } }

  def run_create(**env)
    env.each { |key, value| ENV[key.to_s] = value }
    Rake::Task["admin:create"].reenable
    capture_io { Rake::Task["admin:create"].invoke }.first
  end

  test "makes an admin in the community named" do
    out = run_create(COMMUNITY_SLUG: "other-community", ADMIN_NAME: "Pat Example", ADMIN_EMAIL: "pat@example.com", ADMIN_PASSWORD: @password)

    community = communities(:other_community)
    admin = ActsAsTenant.with_tenant(community) { User.find_by!(email: "pat@example.com") }
    assert admin.admin?
    assert admin.authenticate(@password)
    assert_no_match @password, out
  end

  test "needs the community's slug rather than guessing one" do
    assert_raises(SystemExit) do
      run_create(ADMIN_NAME: "Pat Example", ADMIN_EMAIL: "pat@example.com", ADMIN_PASSWORD: @password)
    end
    assert_not ActsAsTenant.without_tenant { User.exists?(email: "pat@example.com") }
  end

  test "there's only the one admin task" do
    assert_not Rake::Task.task_defined?("admin:create_noninteractive")
  end
end
