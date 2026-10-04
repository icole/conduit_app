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
end
