require "test_helper"

# CON-74: omniauth-rails_csrf_protection is never referenced, only loaded, so
# prove it guards the start of Google sign-in. Without it, another site could
# start a sign-in for you (login CSRF).
class GoogleSignInCsrfTest < ActionDispatch::IntegrationTest
  setup do
    @forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection
  end

  test "starting Google sign-in without the page's token is refused" do
    post "/auth/google_oauth2"
    assert_response :redirect
    assert_match %r{/auth/failure\?message=ActionController%3A%3AInvalidAuthenticityToken}, response.location
  end

  test "the sign-in page's own button starts it" do
    get login_path
    token = css_select("form[action='/auth/google_oauth2'] input[name=authenticity_token]").first["value"]

    post "/auth/google_oauth2", params: { authenticity_token: token }
    assert_response :redirect
    assert_match %r{/auth/google_oauth2/callback}, response.location
  end

  test "a plain link can't start it" do
    get "/auth/google_oauth2"
    assert_response :not_found
  end
end
