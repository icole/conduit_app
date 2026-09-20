# frozen_string_literal: true

require "test_helper"

class Api::LiveblocksControllerTest < ActionDispatch::IntegrationTest
  test "auth is refused for a pending community" do
    host! "pending.test"
    post login_path, params: { email: users(:pending_admin).email, password: "testpassword123" }

    post api_liveblocks_auth_url, params: { room: "document:1" }, as: :json

    assert_response :forbidden
    assert_equal "community_not_active", JSON.parse(response.body)["error"]
  end
end
