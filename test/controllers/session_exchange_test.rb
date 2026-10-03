require "test_helper"
require "minitest/mock"

# CON-54: the Android app signs its web views in with a one-time code that
# lasts a minute, instead of putting its 30-day API token in the URL.
class SessionExchangeTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin_user)
    @auth = { "Authorization" => "Bearer #{JwtService.generate_auth_token(@user)}" }
  end

  # Single use needs a real cache; the test environment's is a null store
  def with_cache(&block)
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new, &block)
  end

  def exchange_token
    post api_v1_session_exchange_url, headers: @auth, as: :json
    assert_response :ok
    JSON.parse(response.body)
  end

  test "the app trades its API token for a code that lasts a minute" do
    with_cache do
      body = exchange_token
      assert_equal 60, body["expires_in"]
      payload = JwtService.decode(body["token"])
      assert_equal "session_exchange", payload[:type]
      assert_in_delta 60.seconds.from_now.to_i, payload[:exp], 5
    end
  end

  test "the code signs the web view in once, and only once" do
    with_cache do
      token = exchange_token["token"]

      get auth_login_url(token: token, redirect_to: "/tasks")
      assert_response :ok
      assert_equal @user.id, session[:user_id]

      reset!
      get auth_login_url(token: token, redirect_to: "/tasks")
      assert_redirected_to login_path
      assert_nil session[:user_id]
    end
  end

  test "an expired code doesn't sign in" do
    with_cache do
      token = exchange_token["token"]
      travel 2.minutes do
        get auth_login_url(token: token)
        assert_redirected_to login_path
      end
    end
  end

  test "no code for someone whose community is suspended" do
    member = users(:pending_admin)
    member.community.update!(status: "suspended")
    post api_v1_session_exchange_url, headers: { "Authorization" => "Bearer #{JwtService.generate_auth_token(member)}" }, as: :json
    assert_response :forbidden
  end

  test "no code without a valid API token" do
    post api_v1_session_exchange_url, as: :json
    assert_response :unauthorized
  end

  test "apps from before the exchange can still sign in with their API token, for now" do
    get auth_login_url(token: JwtService.generate_auth_token(@user))
    assert_response :ok
    assert_equal @user.id, session[:user_id]
  end
end
