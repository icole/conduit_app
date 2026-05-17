# frozen_string_literal: true

require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:email_user)
    @community = communities(:crow_woods)
    host! @community.domain || "example.com"
  end

  # GET /password_reset/new
  test "new renders the request form" do
    get password_reset_new_path
    assert_response :success
    assert_select "input[name='email']"
  end

  # POST /password_reset
  test "create sends reset email for existing user" do
    assert_emails 1 do
      post password_reset_path, params: { email: @user.email }
    end
    assert_redirected_to password_reset_new_path
    assert_match(/instructions/, flash[:notice])
    @user.reload
    assert @user.password_reset_sent_at.present?
  end

  test "create shows same message for non-existent email (no enumeration)" do
    assert_no_emails do
      post password_reset_path, params: { email: "nobody@example.com" }
    end
    assert_redirected_to password_reset_new_path
    assert_match(/instructions/, flash[:notice])
  end

  # GET /password_reset/edit
  test "edit renders the reset form for valid token" do
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)

    get password_reset_edit_path(token: token)
    assert_response :success
    assert_select "input[name='password']"
    assert_select "input[name='password_confirmation']"
  end

  test "edit shows error for invalid token" do
    get password_reset_edit_path(token: "invalid_token")
    assert_redirected_to password_reset_new_path
    assert_match(/expired|invalid/i, flash[:alert])
  end

  test "edit shows error for expired token" do
    @user.update!(password_reset_sent_at: 2.hours.ago)
    token = JwtService.encode(
      { user_id: @user.id, community_id: @user.community_id, type: "password_reset" },
      -1.second
    )

    get password_reset_edit_path(token: token)
    assert_redirected_to password_reset_new_path
    assert_match(/expired|invalid/i, flash[:alert])
  end

  # PATCH /password_reset
  test "update changes password with valid token" do
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)

    patch password_reset_path, params: {
      token: token,
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to login_path
    assert_match(/updated/, flash[:notice])
    @user.reload
    assert @user.authenticate("newpassword123")
    assert_nil @user.password_reset_sent_at
  end

  test "update fails with mismatched passwords" do
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)

    patch password_reset_path, params: {
      token: token,
      password: "newpassword123",
      password_confirmation: "different"
    }

    assert_response :unprocessable_entity
    @user.reload
    assert @user.authenticate("testpassword123") # unchanged
  end

  test "update fails with invalid token" do
    patch password_reset_path, params: {
      token: "invalid",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to password_reset_new_path
    assert_match(/expired|invalid/i, flash[:alert])
  end

  test "update fails with too-short password" do
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)

    patch password_reset_path, params: {
      token: token,
      password: "short",
      password_confirmation: "short"
    }

    assert_response :unprocessable_entity
  end
end
