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

  # CON-34: the token's room used to be whatever the client sent, checked only
  # by its last ":" part. Liveblocks reads a trailing * as a prefix wildcard,
  # so "document:13*" passed for document 13 and opened every room starting
  # with document:13, other communities' documents included.
  def sign_in_with_docs
    post login_path, params: { email: users(:one).email, password: "password" }
    @document = Document.create!(title: "Minutes", storage_type: :native)
    ENV["LIVEBLOCKS_SECRET_KEY"] = "sk_test"
  end

  def granted_rooms
    requests = []
    stub_request(:post, "https://api.liveblocks.io/v2/authorize-user").to_return do |request|
      requests << JSON.parse(request.body)
      { status: 200, body: { token: "t" }.to_json }
    end
    yield
    requests.flat_map { |body| body["permissions"].keys }
  end

  test "the token opens exactly the document's room" do
    sign_in_with_docs
    rooms = granted_rooms { post api_liveblocks_auth_url, params: { room: "document:#{@document.id}" }, as: :json }

    assert_response :ok
    assert_equal [ "document:#{@document.id}" ], rooms
  ensure
    ENV.delete("LIVEBLOCKS_SECRET_KEY")
  end

  test "a wildcard or anything but document:<id> gets no token" do
    sign_in_with_docs
    [ "document:#{@document.id}*", "document:*:#{@document.id}", "other:#{@document.id}", "document:#{@document.id}:extra" ].each do |room|
      rooms = granted_rooms { post api_liveblocks_auth_url, params: { room: room }, as: :json }

      assert_response :bad_request, room
      assert_empty rooms, room
    end
  ensure
    ENV.delete("LIVEBLOCKS_SECRET_KEY")
  end

  test "another community's document gets no token" do
    sign_in_with_docs
    theirs = ActsAsTenant.with_tenant(communities(:other_community)) { Document.create!(title: "Theirs", storage_type: :native) }
    rooms = granted_rooms { post api_liveblocks_auth_url, params: { room: "document:#{theirs.id}" }, as: :json }

    assert_response :not_found
    assert_empty rooms
  ensure
    ENV.delete("LIVEBLOCKS_SECRET_KEY")
  end
end
