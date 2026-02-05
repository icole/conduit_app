require "test_helper"

module Api
  module V1
    class UsersControllerTest < ActionDispatch::IntegrationTest
      setup do
        # Sign in as Mike Davis (fixture :two) so other users are searchable
        sign_in_user(name: "Mike Davis", email: "mike@example.com", uid: "1234567890")
      end

      test "returns matching users by name" do
        get api_v1_users_search_url, params: { q: "Jane" }
        assert_response :success

        json = JSON.parse(response.body)
        assert json.is_a?(Array)
        assert json.any? { |u| u["name"] == "Jane Smith" }
      end

      test "returns empty array for blank query" do
        get api_v1_users_search_url, params: { q: "" }
        assert_response :success

        json = JSON.parse(response.body)
        assert_equal [], json
      end

      test "returns empty array when no users match" do
        get api_v1_users_search_url, params: { q: "zzzznonexistent" }
        assert_response :success

        json = JSON.parse(response.body)
        assert_equal [], json
      end

      test "search is case insensitive" do
        get api_v1_users_search_url, params: { q: "jane" }
        assert_response :success

        json = JSON.parse(response.body)
        assert json.any? { |u| u["name"] == "Jane Smith" }
      end

      test "limits results to 10" do
        get api_v1_users_search_url, params: { q: "e" }
        assert_response :success

        json = JSON.parse(response.body)
        assert json.length <= 10
      end

      test "returns id, name, and avatar_url fields" do
        get api_v1_users_search_url, params: { q: "Jane" }
        assert_response :success

        json = JSON.parse(response.body)
        user = json.first
        assert_not_nil user
        assert user.key?("id")
        assert user.key?("name")
        assert user.key?("avatar_url")
      end

      test "excludes current user from results" do
        get api_v1_users_search_url, params: { q: "Mike" }
        assert_response :success

        json = JSON.parse(response.body)
        # The signed-in user is Mike Davis — he should not appear in results
        refute json.any? { |u| u["name"] == "Mike Davis" }
      end

      test "requires authentication" do
        delete logout_url
        get api_v1_users_search_url, params: { q: "Jane" }
        assert_response :redirect
      end
    end
  end
end
