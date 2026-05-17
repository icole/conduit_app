# frozen_string_literal: true

require "test_helper"

class JwtServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:email_user)
  end

  test "generate_password_reset_token creates a valid token" do
    token = JwtService.generate_password_reset_token(@user)
    assert token.present?

    decoded = JwtService.decode(token)
    assert_equal @user.id, decoded[:user_id]
    assert_equal @user.community_id, decoded[:community_id]
    assert_equal "password_reset", decoded[:type]
    assert decoded[:exp].present?
    assert decoded[:iat].present?
  end

  test "verify_password_reset_token returns user for valid token" do
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)

    result = JwtService.verify_password_reset_token(token)
    assert_equal @user, result
  end

  test "verify_password_reset_token returns nil for expired token" do
    @user.update!(password_reset_sent_at: 2.hours.ago)
    token = JwtService.encode(
      { user_id: @user.id, community_id: @user.community_id, type: "password_reset" },
      -1.hour
    )

    result = JwtService.verify_password_reset_token(token)
    assert_nil result
  end

  test "verify_password_reset_token returns nil for wrong type" do
    token = JwtService.generate_auth_token(@user)

    result = JwtService.verify_password_reset_token(token)
    assert_nil result
  end

  test "verify_password_reset_token returns nil if password_reset_sent_at is nil (already used)" do
    @user.update!(password_reset_sent_at: nil)
    token = JwtService.generate_password_reset_token(@user)

    result = JwtService.verify_password_reset_token(token)
    assert_nil result
  end

  test "verify_password_reset_token returns nil if token issued before password_reset_sent_at" do
    old_time = 2.hours.ago
    token = JwtService.encode(
      { user_id: @user.id, community_id: @user.community_id, type: "password_reset", iat: old_time.to_i },
      1.hour
    )
    @user.update!(password_reset_sent_at: Time.current)

    result = JwtService.verify_password_reset_token(token)
    assert_nil result
  end
end
