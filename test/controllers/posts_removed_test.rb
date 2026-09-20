# frozen_string_literal: true

require "test_helper"

# Posts were removed; the routes and model must be gone.
class PostsRemovedTest < ActionDispatch::IntegrationTest
  test "post routes no longer exist" do
    post "/posts", params: { post: { content: "hi" } }
    assert_response :not_found
  end

  test "Post is no longer a model" do
    assert_not Object.const_defined?(:Post)
  end
end
