# frozen_string_literal: true

require "test_helper"

class TimeEntriesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(@user)
    @role = roles(:garden_maven)
    @entry = time_entries(:maven_task_entry)
  end

  test "should get index" do
    get time_entries_url
    assert_response :success
  end

  test "should create task time entry" do
    task = tasks(:assigned_task)
    assert_difference("TimeEntry.count") do
      post role_time_entries_url(@role), params: { time_entry: {
        hours: 1.5,
        logged_on: Date.current,
        entry_type: "task",
        task_id: task.id
      } }
    end
    assert_redirected_to role_url(@role)
  end

  test "should create reconciliation entry" do
    assert_difference("TimeEntry.count") do
      post role_time_entries_url(@role), params: { time_entry: {
        hours: 3.0,
        logged_on: Date.current,
        entry_type: "reconciliation",
        note: "General maintenance conversations"
      } }
    end
    assert_redirected_to role_url(@role)
  end

  test "should destroy time entry" do
    assert_difference("TimeEntry.count", -1) do
      delete time_entry_url(@entry)
    end
    assert_redirected_to time_entries_url
  end

  private

  def sign_in_as(user)
    post login_url, params: { email: user.email, password: "password" }
    assert_equal user.id, session[:user_id], "Failed to sign in as #{user.email}"
  end
end
