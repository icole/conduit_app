require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
    Rack::Attack.reset!
  end

  teardown do
    Rack::Attack.reset!
    Rack::Attack.cache.store = @original_cache
  end

  test "throttles excessive login attempts by IP" do
    21.times do
      post "/login", params: { session: { email: "test@example.com", password: "wrong" } }
    end

    assert_equal 429, response.status
  end

  test "allows normal login attempts" do
    5.times do
      post "/login", params: { session: { email: "test@example.com", password: "wrong" } }
    end

    assert_not_equal 429, response.status
  end

  test "throttles excessive password reset requests" do
    6.times do
      post "/password_reset", params: { password_reset: { email: "test@example.com" } }
    end

    assert_equal 429, response.status
  end

  # rack-attack takes Rails.cache the first time it's used. Tests that swap in
  # a real cache (SessionExchangeTest) could hand it theirs for good, and later
  # signups in that worker were throttled (429). It's fixed at boot instead.
  test "throttling keeps the cache store it booted with" do
    Rack::Attack.cache.store = @original_cache
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) { Rack::Attack.cache.store }

    assert_same @original_cache, Rack::Attack.cache.store
    assert_kind_of ActiveSupport::Cache::NullStore, Rack::Attack.cache.store, "tests run with Rails' null cache"
  end
end
