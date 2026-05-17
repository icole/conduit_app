# frozen_string_literal: true

require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:email_user)
    @token = "test_token_abc123"
    ActsAsTenant.current_tenant = communities(:crow_woods)
  end

  test "password_reset sends email to user with reset link" do
    email = UserMailer.password_reset(@user, @token)

    assert_equal ["emailuser@example.com"], email.to
    assert_equal "Reset your password", email.subject
    assert_match "password_reset/edit", email.body.encoded
    assert_match @token, email.body.encoded
  end

  test "password_reset email contains user name" do
    email = UserMailer.password_reset(@user, @token)

    assert_match @user.name, email.body.encoded
  end
end
