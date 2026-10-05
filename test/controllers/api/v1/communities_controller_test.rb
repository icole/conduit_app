require "test_helper"

module Api
  module V1
    # CON-34: GET /api/v1/communities listed every active community's name and
    # domain to anyone. The apps find one community by name instead
    # (community_lookup_test.rb) and have since 9f98763.
    class CommunitiesControllerTest < ActionDispatch::IntegrationTest
      test "there's no public list of communities" do
        get "/api/v1/communities", as: :json

        assert_response :not_found
      end
    end
  end
end
