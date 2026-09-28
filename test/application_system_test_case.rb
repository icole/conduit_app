require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # CI machines are slower than a laptop: a form that checks a password or
  # deletes a user can take over Capybara's default 2s to land, and flash
  # messages hide themselves after 3s, so waiting 2s made those tests flaky.
  Capybara.default_max_wait_time = 5

  # The Content-Security-Policy is enforced outside production, and a blocked
  # script fails silently — the page just quietly does nothing, which is how a
  # CSP rollout breaks a feature without anyone noticing. So every system test
  # doubles as a CSP check: this listener is installed before any page script
  # runs, and the teardown below fails the test on anything the policy blocked.
  #
  # Chrome reports a blocked inline <script> as `script-src-elem` at load time,
  # but a blocked `onclick=` attribute as `script-src-attr` only when something
  # actually invokes it. The clicking these tests already do is what gives us
  # coverage of the second kind.
  CSP_VIOLATION_COLLECTOR = <<~JS
    if (!window.__cspViolations) {
      window.__cspViolations = [];
      document.addEventListener("securitypolicyviolation", (event) => {
        window.__cspViolations.push(
          [ event.effectiveDirective, event.blockedURI, event.sourceFile, event.lineNumber ]
            .filter((part) => part !== "" && part !== null && part !== undefined)
            .join(" ")
        );
      });
    }
  JS

  OmniAuth.config.test_mode = true

  setup { before_each_system_test }

  # Only when the test was otherwise passing: a CSP violation is a worse
  # explanation than a real failure, and stacking both just obscures the real one.
  teardown { assert_no_csp_violations if passed? }

  # Start every test signed out. Capybara's reset between tests clears cookies
  # and only then navigates away, so a background request finishing in between
  # (the dashboard lazy-loads frames) can set a fresh session cookie. The next
  # test's Google sign-in would then link accounts instead of switching users
  # and run as the wrong person. Nothing is loaded yet here, so this is final.
  def before_each_system_test
    browser = page.driver.browser
    return unless browser.respond_to?(:execute_cdp)

    browser.execute_cdp("Network.clearBrowserCookies")
    browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: CSP_VIOLATION_COLLECTOR)
  end

  def assert_no_csp_violations
    violations = csp_violations
    assert_empty violations,
      "Content-Security-Policy blocked #{violations.size} resource(s):\n  " + violations.join("\n  ")
  end

  # Empty when no page has been loaded yet, or when the browser is already gone.
  def csp_violations
    page.evaluate_script("window.__cspViolations || []")
  rescue StandardError
    []
  end

  def sign_in_user(user_attrs = {})
    default_attrs = {
      provider: "google_oauth2",
      uid: "test_oauth_uid_999",  # Non-conflicting with fixtures
      info: {
        name: "Test User",
        email: "test_oauth_user@example.com"
      }
    }

    auth = default_attrs.deep_merge(user_attrs)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(auth)

    # A brand-new account needs an invitation, exactly as in production.
    unless User.exists?(provider: "google_oauth2", uid: auth[:uid].to_s)
      visit accept_invitation_path(Invitation.create!.token)
    end

    visit "/auth/google_oauth2/callback"
  end

  # Sign in as a specific fixture user
  def sign_in_as(user)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: user.provider || "google_oauth2",
      uid: user.uid,
      info: {
        name: user.name,
        email: user.email
      }
    )

    visit "/auth/google_oauth2/callback"
  end
end
