# frozen_string_literal: true

require "test_helper"

class JwtEmailVerificationTest < ActiveSupport::TestCase
  setup do
    @user = users(:unverified_user)
  end

  test "round-trips a verification token" do
    @user.update!(email_verification_sent_at: Time.current)
    token = JwtService.generate_email_verification_token(@user)
    assert_equal @user, JwtService.verify_email_verification_token(token)
  end

  test "rejects a token issued before the latest send (single use)" do
    @user.update!(email_verification_sent_at: 1.minute.ago)
    token = JwtService.generate_email_verification_token(@user)
    @user.update!(email_verification_sent_at: 1.minute.from_now)

    assert_nil JwtService.verify_email_verification_token(token)
  end

  test "rejects a token once the user has no pending verification" do
    @user.update!(email_verification_sent_at: Time.current)
    token = JwtService.generate_email_verification_token(@user)
    @user.verify_email!

    assert_nil JwtService.verify_email_verification_token(token)
  end

  test "rejects tokens of another type" do
    assert_nil JwtService.verify_email_verification_token(JwtService.generate_auth_token(@user))
  end
end
