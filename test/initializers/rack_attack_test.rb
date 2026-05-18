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
end
