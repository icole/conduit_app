# frozen_string_literal: true

require "test_helper"

class Api::V1::CommunityLookupTest < ActionDispatch::IntegrationTest
  test "finds a community by slug" do
    get lookup_api_v1_communities_url(slug: "crow-woods")

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "crow-woods", json["slug"]
    assert_equal communities(:crow_woods).domain, json["domain"]
    assert_equal "active", json["status"]
  end

  test "finds a community by domain" do
    get lookup_api_v1_communities_url(slug: communities(:crow_woods).domain)

    assert_response :success
    assert_equal "crow-woods", JSON.parse(response.body)["slug"]
  end

  test "is case and whitespace insensitive" do
    get lookup_api_v1_communities_url(slug: "  Crow-Woods  ")

    assert_response :success
    assert_equal "crow-woods", JSON.parse(response.body)["slug"]
  end

  test "finds a community by the name people know it by" do
    [ "Crow Woods", "crow woods", "  CROW   WOODS ", "Crow-Woods" ].each do |typed|
      get lookup_api_v1_communities_url(slug: typed)
      assert_response :success, typed
      assert_equal "crow-woods", JSON.parse(response.body)["slug"], typed
    end
  end

  test "a name that isn't quite right still isn't found, and nothing else is revealed" do
    [ "Crow", "Crow Wood", "crowwoods" ].each do |typed|
      get lookup_api_v1_communities_url(slug: typed)
      assert_response :not_found, typed
    end
  end

  test "a suspended community isn't found by name either" do
    get lookup_api_v1_communities_url(slug: "Suspended Community")
    assert_response :not_found
  end

  test "finds a pending community so its founder can sign in" do
    get lookup_api_v1_communities_url(slug: "pending-community")

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "pending", json["status"]
  end

  test "does not find a suspended community" do
    get lookup_api_v1_communities_url(slug: "suspended-community")
    assert_response :not_found
  end

  test "returns 404 for an unknown slug" do
    get lookup_api_v1_communities_url(slug: "nope")

    assert_response :not_found
    assert_equal "community_not_found", JSON.parse(response.body)["error"]
  end

  test "requires a slug" do
    get lookup_api_v1_communities_url
    assert_response :bad_request
  end

  test "needs no authentication" do
    get lookup_api_v1_communities_url(slug: "crow-woods")
    assert_response :success
  end
end
