require "test_helper"

module Api
  module V1
    class CommunitiesControllerTest < ActionDispatch::IntegrationTest
      setup do
        # Create test communities with different names to test ordering
        @community_alpha = Community.create!(
          name: "Alpha Community",
          slug: "alpha",
          domain: "alpha.test"
        )
        @community_beta = Community.create!(
          name: "Beta Community",
          slug: "beta",
          domain: "beta.test"
        )
        @community_gamma = Community.create!(
          name: "Gamma Community",
          slug: "gamma",
          domain: "gamma.test"
        )
      end

      test "should return HTTP 200 OK response" do
        get api_v1_communities_url
        assert_response :success
      end

      test "should return all communities from the database" do
        get api_v1_communities_url
        json_response = JSON.parse(response.body)

        assert json_response.length >= 3, "Should return at least the 3 test communities"
        community_ids = json_response.map { |c| c["id"] }
        assert_includes community_ids, @community_alpha.id
        assert_includes community_ids, @community_beta.id
        assert_includes community_ids, @community_gamma.id
      end

      test "should return communities ordered by name" do
        get api_v1_communities_url
        json_response = JSON.parse(response.body)

        community_names = json_response.map { |c| c["name"] }
        # Verify that communities are ordered alphabetically
        assert_equal community_names, community_names.sort

        # Verify our test communities are in the correct order relative to each other
        alpha_index = community_names.index("Alpha Community")
        beta_index = community_names.index("Beta Community")
        gamma_index = community_names.index("Gamma Community")

        assert alpha_index < beta_index, "Alpha should come before Beta"
        assert beta_index < gamma_index, "Beta should come before Gamma"
      end

      test "should include id, name, domain, and slug for each community" do
        get api_v1_communities_url
        json_response = JSON.parse(response.body)

        json_response.each do |community_json|
          assert community_json.key?("id")
          assert community_json.key?("name")
          assert community_json.key?("domain")
          assert community_json.key?("slug")
        end

        # Verify specific values for one community
        alpha_json = json_response.find { |c| c["slug"] == "alpha" }
        assert_equal @community_alpha.id, alpha_json["id"]
        assert_equal "Alpha Community", alpha_json["name"]
        assert_equal "alpha.test", alpha_json["domain"]
        assert_equal "alpha", alpha_json["slug"]
      end

      test "should be accessible without authentication" do
        # Make request without any authentication headers or session
        get api_v1_communities_url
        assert_response :success

        json_response = JSON.parse(response.body)
        assert json_response.length > 0, "Should return communities even without authentication"
      end

      test "should return an empty array if no communities exist" do
        # Delete all records that depend on users/communities
        ActiveRecord::Base.connection.execute("TRUNCATE calendar_shares CASCADE")
        ActiveRecord::Base.connection.execute("TRUNCATE communities CASCADE")

        get api_v1_communities_url
        assert_response :success

        json_response = JSON.parse(response.body)
        assert_equal [], json_response
        assert_kind_of Array, json_response
      end
    end
  end
end
