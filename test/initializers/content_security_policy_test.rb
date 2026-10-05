require "test_helper"

# CON-53: CSP violation reports go to Sentry's security endpoint, derived from
# the DSN production already has, so there's no separate secret to forget
class ContentSecurityPolicyReportsTest < ActiveSupport::TestCase
  test "the report address comes from the Sentry DSN" do
    assert_equal "https://o42.ingest.us.sentry.io/api/4507/security/?sentry_key=abc123",
      SentryCspReportUri.from_dsn("https://abc123@o42.ingest.us.sentry.io/4507")
  end

  test "no address without a usable DSN" do
    assert_nil SentryCspReportUri.from_dsn(nil)
    assert_nil SentryCspReportUri.from_dsn("")
    assert_nil SentryCspReportUri.from_dsn("not a dsn")
    assert_nil SentryCspReportUri.from_dsn("https://o42.ingest.us.sentry.io/4507"), "no key"
  end

  # Found by browsing production with the policy reporting (CON-53): the Google
  # button posts to our /auth/google_oauth2, which redirects to Google, and
  # Chrome applies form-action to that redirect. Enforced, it would have
  # stopped Google sign-in on the web.
  test "form-action lets the Google sign-in redirect through" do
    policy = Rails.application.config.content_security_policy.build(ActionDispatch::Request.new({}))
    form_action = policy[/form-action [^;]+/]

    assert_includes form_action.split, "https://accounts.google.com"
    assert_includes form_action.split, "'self'"
  end
end
