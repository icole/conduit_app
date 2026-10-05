require "test_helper"
require "minitest/mock"

# Sign in with Apple from the iPhone app (CON-64, App Store guideline 4.8),
# on the same terms as Google: the verified token is the identity, the
# community is named, and new accounts need an invitation
class Api::V1::AppleAuthTest < ActionDispatch::IntegrationTest
  setup { @community = communities(:crow_woods) }

  def sign_in_with_apple(claims, **params)
    AppleIdTokenVerifier.stub(:verify, claims) do
      post api_v1_apple_auth_url, params: { identity_token: "token", community_domain: @community.domain, **params }, as: :json
    end
  end

  def claims(sub: "apple-123", email: users(:one).email)
    { "sub" => sub, "email" => email, "email_verified" => "true" }
  end

  test "a member signs in with the email they share with Apple, and Apple remembers them" do
    sign_in_with_apple(claims)

    assert_response :ok
    assert JSON.parse(response.body)["auth_token"].present?
    assert_equal "apple-123", users(:one).reload.apple_uid
  end

  test "once linked, they're found by their Apple ID even with Hide My Email" do
    users(:one).update!(apple_uid: "apple-123")
    sign_in_with_apple(claims(email: "x7k2@privaterelay.appleid.com"))

    assert_response :ok
    assert_equal users(:one).id, JSON.parse(response.body).dig("user", "id")
  end

  test "someone new needs an invitation" do
    sign_in_with_apple(claims(sub: "apple-new", email: "newcomer@example.com"))
    assert_response :forbidden
    assert_not User.exists?(email: "newcomer@example.com")

    invitation = Invitation.create!
    sign_in_with_apple(claims(sub: "apple-new", email: "newcomer@example.com"),
      invitation_token: invitation.token, given_name: "New", family_name: "Comer")
    assert_response :ok
    newcomer = User.find_by!(email: "newcomer@example.com")
    assert_equal [ "New Comer", "apple-new" ], [ newcomer.name, newcomer.apple_uid ]
    assert newcomer.email_verified?
    assert_nil newcomer.password_digest
  end

  test "an invalid token, or none, signs no one in" do
    sign_in_with_apple(nil)
    assert_response :unauthorized

    post api_v1_apple_auth_url, params: { community_domain: @community.domain }, as: :json
    assert_response :bad_request
  end

  test "a token whose email Apple hasn't verified is refused, and the log says so" do
    log = StringIO.new
    Rails.logger.stub(:warn, ->(message) { log.puts(message) }) do
      sign_in_with_apple(claims.merge("email_verified" => "false"))
    end
    assert_response :unauthorized
    assert_match(/email not verified/, log.string)
  end

  test "the community has to be named" do
    AppleIdTokenVerifier.stub(:verify, claims) do
      post api_v1_apple_auth_url, params: { identity_token: "token" }, as: :json
    end
    assert_response :bad_request
  end
end
