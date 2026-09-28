# frozen_string_literal: true

require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @user = users(:email_user)
    @community = communities(:crow_woods)
    host! @community.domain || "example.com"
    post login_path, params: { email: @admin.email, password: "password" }
  end

  test "destroy removes the user and enqueues Stream user removal" do
    assert_enqueued_with(job: StreamUserRemovalJob, args: [ @user.id.to_s ]) do
      delete user_path(@user)
    end

    assert_redirected_to users_path
    assert_nil User.find_by(id: @user.id)
  end

  test "destroying your own admin account does not enqueue Stream user removal" do
    assert_no_enqueued_jobs(only: StreamUserRemovalJob) do
      delete user_path(@admin)
    end

    assert_redirected_to users_path
    assert User.exists?(@admin.id)
  end
end
