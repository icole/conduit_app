require "test_helper"

# The verification link has to open somewhere that loads. For a new community
# it came out as https://example.com/...: the email was queued with no
# community set, so the mailer fell back to production's placeholder host.
class VerificationEmailLinkTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def verification_link
    mail = ActionMailer::Base.deliveries.reverse.find { |m| m.subject.match?(/verify/i) }
    (mail.html_part || mail).body.decoded[%r{https?://[^/"\s]+/email_verification/[^"\s<]+}]
  end

  test "starting a community: the link is on the API domain, since the community's own domain doesn't load yet" do
    ActsAsTenant.current_tenant = nil
    perform_enqueued_jobs do
      post community_signups_path, params: {
        community: { name: "Willow Creek" },
        user: { name: "Founder", email: "founder@example.com", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_match %r{\Ahttps://api\.conduitcoho\.app/email_verification/}, verification_link
  end

  test "a community with its own domain gets links on it, however the email was queued" do
    ActsAsTenant.current_tenant = nil
    perform_enqueued_jobs { ActsAsTenant.without_tenant { users(:unverified_user).send_email_verification! } }

    assert_match %r{\Ahttps://crowwoods\.test/email_verification/}, verification_link
  end

  test "opening the link where you're not signed in says it worked" do
    user = users(:unverified_user)
    host! "api.conduitcoho.app"
    get verify_email_path(JwtService.generate_email_verification_token(user))

    assert_response :success
    assert_match "Your email address is verified", response.body
    assert user.reload.email_verified_at
  end
end
