# frozen_string_literal: true

require "test_helper"

class UserMailerVerifyEmailTest < ActionMailer::TestCase
  test "verify_email links to the verification URL" do
    user = users(:unverified_user)
    email = UserMailer.verify_email(user, "tok-123")

    assert_equal [ user.email ], email.to
    assert_match(/verify/i, email.subject)
    assert_match "/email_verification/tok-123", email.body.encoded
  end
end
