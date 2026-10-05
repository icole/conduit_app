require "test_helper"
require "minitest/mock"

# Sign in with Apple (CON-64): the identity token is a JWT signed with one of
# Apple's published keys, issued by Apple, for our iPhone app
class AppleIdTokenVerifierTest < ActiveSupport::TestCase
  KEY = OpenSSL::PKey::RSA.generate(2048)
  KID = "test-key".freeze

  setup do
    Rails.cache.clear
    jwk = JWT::JWK.new(KEY, kid: KID)
    stub_request(:get, AppleIdTokenVerifier::KEYS_URI).to_return(body: { keys: [ jwk.export ] }.to_json)
  end

  def token(claims = {}, key: KEY, kid: KID)
    payload = { iss: "https://appleid.apple.com", aud: "com.colecoding.ConduitApp", sub: "apple-123",
                email: "member@example.com", email_verified: "true", exp: 10.minutes.from_now.to_i, iat: Time.current.to_i }
    JWT.encode(payload.merge(claims), key, "RS256", { kid: kid })
  end

  test "a token Apple signed for our app gives its claims" do
    claims = AppleIdTokenVerifier.verify(token)

    assert_equal "apple-123", claims["sub"]
    assert_equal "member@example.com", claims["email"]
  end

  test "anything else is refused" do
    assert_nil AppleIdTokenVerifier.verify(token({ aud: "com.someone.else" })), "another app's"
    assert_nil AppleIdTokenVerifier.verify(token({ iss: "https://evil.example" })), "not Apple's"
    assert_nil AppleIdTokenVerifier.verify(token({ exp: 1.minute.ago.to_i })), "expired"
    assert_nil AppleIdTokenVerifier.verify(token(key: OpenSSL::PKey::RSA.generate(2048))), "not signed by Apple"
    assert_nil AppleIdTokenVerifier.verify(""), "blank"
    assert_nil AppleIdTokenVerifier.verify("not.a.jwt"), "garbage"
  end

  test "a refusal is logged with its reason, so a failed sign-in can be traced" do
    log = StringIO.new
    Rails.logger.stub(:warn, ->(message) { log.puts(message) }) do
      AppleIdTokenVerifier.verify(token({ aud: "com.someone.else" }))
    end
    assert_match(/JWT::InvalidAudError.*com\.someone\.else/, log.string)
  end
end
