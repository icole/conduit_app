require "test_helper"
require "minitest/mock"
require_relative "../support/fake_stream_client"

# CON-80: chat tokens expire, and clients that can fetch a new one get
# expiring tokens. Apps installed before they could still get the old kind.
class StreamTokenExpiryTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin_user)
    @fake = FakeStreamClient.new
  end

  def with_stream(&block)
    StreamChatClient.stub(:configured?, true) { StreamChatClient.stub(:client, @fake, &block) }
  end

  test "an expiring token carries an expiry within the token lifetime; the old kind has none" do
    client = StreamChat::Client.new("test-key", "test-secret")
    StreamChatClient.stub(:client, client) do
      expiring = JWT.decode(StreamChatClient.token_for(@user.id, expiring: true), "test-secret", true, algorithm: "HS256").first
      assert_in_delta (Time.current + StreamChatClient::TOKEN_TTL).to_i, expiring["exp"], 5

      lasting = JWT.decode(StreamChatClient.token_for(@user.id, expiring: false), "test-secret", true, algorithm: "HS256").first
      assert_nil lasting["exp"]
    end
  end

  test "apps get an expiring token from the API when they ask for one, and the old kind otherwise" do
    auth = { "Authorization" => "Bearer #{JwtService.generate_auth_token(@user)}" }
    with_stream do
      get api_v1_stream_token_url(expiring: 1), headers: auth, as: :json
      assert_response :ok
      get api_v1_stream_token_url, headers: auth, as: :json
      assert_response :ok
    end
    assert_not_nil @fake.tokens.first[:exp], "asked for an expiring token"
    assert_nil @fake.tokens.last[:exp], "an app from before expiring tokens"
  end

  test "the iPhone app's token endpoint works the same way" do
    sign_in_user({ uid: @user.uid, name: @user.name, email: @user.email })
    with_stream do
      get "/chat/token.json", params: { expiring: 1 }
      assert_response :ok
      get "/chat/token.json"
      assert_response :ok
    end
    assert_not_nil @fake.tokens.first[:exp]
    assert_nil @fake.tokens.last[:exp]
  end

  test "the web chat gets an expiring token, and pages no longer embed one" do
    communities(:crow_woods).update!(settings: (communities(:crow_woods).settings || {}).merge("chat_enabled" => true))
    sign_in_user({ uid: @user.uid, name: @user.name, email: @user.email })
    with_stream do
      get chat_index_url
      assert_response :ok
      assert_select "meta[name='stream-token']", count: 0
    end
    assert @fake.tokens.any?, "the chat page minted a token"
    assert @fake.tokens.all? { |token| token[:exp] }, "every token for the web is an expiring one"
  end
end
