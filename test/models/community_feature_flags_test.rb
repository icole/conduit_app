# frozen_string_literal: true

require "test_helper"

class CommunityFeatureFlagsTest < ActiveSupport::TestCase
  test "flags default to off for a new community" do
    community = Community.new(name: "New", slug: "new", domain: "new.test")
    assert_not community.chat_enabled?
    assert_not community.collaborative_docs_enabled?
  end

  test "flags are read from settings" do
    assert communities(:crow_woods).chat_enabled?
    assert communities(:crow_woods).collaborative_docs_enabled?
    assert_not communities(:other_community).chat_enabled?
  end

  test "flag setters persist into settings without clobbering other keys" do
    community = communities(:other_community)
    community.update!(settings: { "google_calendar_id" => "cal" })

    community.chat_enabled = true
    community.save!

    community.reload
    assert community.chat_enabled?
    assert_equal "cal", community.google_calendar_id
  end

  test "chat_available? needs both an active community and the flag" do
    assert communities(:crow_woods).chat_available?
    assert_not communities(:other_community).chat_available?, "active but chat_enabled off"

    disabled = communities(:crow_woods)
    disabled.chat_enabled = false
    assert_not disabled.chat_available?
  end

  test "collaboration_available? needs both an active community and the flag" do
    assert communities(:crow_woods).collaboration_available?
    assert_not communities(:other_community).collaboration_available?
  end
end
