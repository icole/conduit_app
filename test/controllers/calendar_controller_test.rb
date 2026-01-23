# frozen_string_literal: true

require "test_helper"

class CalendarControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in_user
    get calendar_index_url
    assert_response :success
  end

  test "index sets date range for full month including past events" do
    sign_in_user
    travel_to Date.new(2025, 1, 15) do
      get calendar_index_url, params: { start_date: "2025-01-15" }
      assert_response :success

      # Verify that @date is set to the requested date
      assert_equal Date.new(2025, 1, 15), assigns(:date)
    end
  end

  test "index uses current date when start_date not provided" do
    sign_in_user
    travel_to Date.new(2025, 2, 20) do
      get calendar_index_url
      assert_response :success
      assert_equal Date.new(2025, 2, 20), assigns(:date)
    end
  end

  test "index sets calendar sharing variables" do
    sign_in_user
    get calendar_index_url
    assert_response :success

    # These variables should be set for the subscribe button
    assert_not_nil assigns(:google_calendar_configured)
    assert_not_nil assigns(:calendar_already_shared)
  end
end
