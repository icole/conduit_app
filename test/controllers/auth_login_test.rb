require "test_helper"

# The apps open GET /auth_login?token=...&redirect_to=/tasks in their web
# views to turn their sign-in token into a session, then move on.
class AuthLoginTest < ActionDispatch::IntegrationTest
  setup do
    @token = JwtService.generate_auth_token(users(:one))
  end

  def script
    css_select("script").first
  end

  test "signs in and moves on to the requested page with a script the CSP allows" do
    get "/auth_login", params: { token: @token, redirect_to: "/tasks" }
    assert_response :success
    assert script["nonce"].present?, "the inline script needs the CSP nonce, or browsers enforcing the CSP block it"
    assert_includes script.text, %("/tasks")

    get "/tasks"
    assert_response :success
  end

  test "a redirect_to that tries to break out of the script stays a harmless string" do
    get "/auth_login", params: { token: @token, redirect_to: "/';alert(1);'</script><script>alert(2)" }
    assert_response :success
    assert_equal 1, css_select("script").size, "no injected script element"
    # The whole value stays inside one double-quoted string
    assert_match(/window\.location\.href = "[^"]*";\s*\z/, script.text)
  end

  test "an outside address goes to the home page instead" do
    get "/auth_login", params: { token: @token, redirect_to: "https://evil.example/" }
    assert_includes script.text, %("/")
    assert_not_includes script.text, "evil.example"
  end
end
