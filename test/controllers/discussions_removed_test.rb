# frozen_string_literal: true

require "test_helper"

# Discussions were removed; the routes must be gone, not just hidden.
class DiscussionsRemovedTest < ActionDispatch::IntegrationTest
  test "discussion routes no longer exist" do
    get "/discussion_topics"
    assert_response :not_found

    get "/discussion_topics/1"
    assert_response :not_found
  end

  test "DiscussionTopic is no longer a model" do
    assert_not Object.const_defined?(:DiscussionTopic)
  end
end
