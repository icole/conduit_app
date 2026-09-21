# frozen_string_literal: true

require "test_helper"

class CommunitySignupsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  VALID = {
    community: { name: "Willow Creek" },
    user: { name: "Founder", email: "founder@example.com",
            password: "password123", password_confirmation: "password123" }
  }.freeze

  test "the signup form is reachable without a tenant or a session" do
    get new_community_signup_path
    assert_response :success
    assert_select "form"
  end

  test "creating a community makes it pending with an admin founder" do
    assert_difference [ "Community.count", "User.unscoped.count" ], 1 do
      post community_signups_path, params: VALID
    end

    community = Community.find_by(slug: "willow-creek")
    assert community.pending?
    assert_not community.chat_enabled?, "metered features stay off until approved"
    assert_equal "willow-creek.conduitcoho.app", community.domain

    founder = ActsAsTenant.with_tenant(community) { User.find_by(email: "founder@example.com") }
    assert founder.admin?
    assert_equal community.id, founder.community_id
  end

  test "the founder is signed in and sent a verification email" do
    assert_enqueued_email_with UserMailer, :verify_email, args: ->(args) { args.first.email == "founder@example.com" } do
      post community_signups_path, params: VALID
    end

    community = Community.find_by(slug: "willow-creek")
    founder = ActsAsTenant.with_tenant(community) { User.find_by(email: "founder@example.com") }
    assert_equal founder.id, session[:user_id]
    assert_equal community.id, session[:community_id]
    assert_not founder.email_verified?
    assert_redirected_to root_path
  end

  test "slugs are uniquified when a community name is taken" do
    post community_signups_path, params: VALID
    reset!

    post community_signups_path, params: {
      community: { name: "Willow Creek" },
      user: { name: "Other", email: "other@example.com", password: "password123", password_confirmation: "password123" }
    }

    slugs = Community.where("slug LIKE 'willow-creek%'").pluck(:slug).sort
    assert_equal [ "willow-creek", "willow-creek-2" ], slugs
    assert_equal 2, Community.where("domain LIKE 'willow-creek%'").distinct.count(:domain)
  end

  test "a blank community name re-renders without creating anything" do
    assert_no_difference [ "Community.count", "User.unscoped.count" ] do
      post community_signups_path, params: VALID.deep_merge(community: { name: "" })
    end
    assert_response :unprocessable_entity
  end

  test "an invalid user re-renders and creates no community" do
    assert_no_difference [ "Community.count", "User.unscoped.count" ] do
      post community_signups_path, params: VALID.deep_merge(user: { password: "short", password_confirmation: "short" })
    end
    assert_response :unprocessable_entity
  end

  test "the same email may found communities in different tenants" do
    post community_signups_path, params: VALID
    reset!

    assert_difference "Community.count", 1 do
      post community_signups_path, params: {
        community: { name: "Second Place" },
        user: { name: "Founder", email: "founder@example.com", password: "password123", password_confirmation: "password123" }
      }
    end
  end

  test "founding a community does not require an invitation" do
    post community_signups_path, params: VALID
    assert_redirected_to root_path
    assert_not_nil session[:user_id]
  end
end
