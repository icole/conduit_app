require "test_helper"

# The Android app's path configuration decides which pages open as sheets.
class AndroidPathConfigurationTest < ActiveSupport::TestCase
  CONFIG = Rails.root.join("android/app/src/main/assets/json/path-configuration.json")

  # Like the app: the last matching rule wins
  def context_for(path)
    JSON.parse(CONFIG.read)["rules"].reverse.find { |rule| rule["patterns"].any? { |pattern| Regexp.new(pattern).match?(path) } }
      &.dig("properties", "context")
  end

  test "new and edit pages open as sheets, with or without a query string" do
    %w[/meals/new /tasks/9/edit /tasks/new?workstream_id=3 /tasks/9/edit?return_to=%2Fworkstreams%2F3
       /calendar_events/new /calendar_events/abc/edit].each do |path|
      assert_equal "modal", context_for(path), path
    end
  end

  test "other pages and document editing stay full screen" do
    %w[/tasks /tasks?tab=my /meals/5 /documents/3/edit].each do |path|
      assert_nil context_for(path), path
    end
  end
end
