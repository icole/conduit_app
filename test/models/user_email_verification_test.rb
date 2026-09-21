# frozen_string_literal: true

require "test_helper"

class UserEmailVerificationTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "a user registered with a password starts unverified" do
    user = User.create!(name: "New", email: "new@example.com", password: "password123", password_confirmation: "password123")
    assert_not user.email_verified?
  end

  test "send_email_verification! stamps sent_at and enqueues the email" do
    user = users(:unverified_user)

    assert_enqueued_emails 1 do
      user.send_email_verification!
    end
    assert_in_delta Time.current, user.reload.email_verification_sent_at, 5
  end

  test "verify_email! marks the user verified and clears sent_at" do
    user = users(:unverified_user)
    user.verify_email!

    assert user.reload.email_verified?
    assert_nil user.email_verification_sent_at
  end

  test "changing a verified user's email un-verifies it and sends a new verification" do
    user = users(:email_user)
    assert user.email_verified?

    assert_enqueued_emails 1 do
      user.update!(email: "changed@example.com")
    end
    assert_not user.reload.email_verified?
  end

  test "users created from Google sign-in are verified immediately" do
    auth = OpenStruct.new(provider: "google_oauth2", uid: "verified-uid",
      info: OpenStruct.new(email: "g@example.com", name: "G", image: nil))
    invitation = Invitation.create!

    user = User.from_omniauth(auth, invitation.token)
    user.save!

    assert user.email_verified?
  end
end
